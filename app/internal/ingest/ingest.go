// Package ingest loads collector batches from raw/ into the record table.
//
// A batch is one raw/<feed>/ingest_dt=<date>/run=<time>/ prefix that holds a
// _SUCCESS marker. Run discovers batches for every feed in feed_manifest,
// skips batches already in the ledger, and loads the rest in run order. Each
// batch commits in one transaction. A feed of kind latest loads only its
// newest batch and records the others as superseded.
//
// A feed's history is complete when a pass has listed its whole history and
// decided every batch in it. Until then, discovery lists the whole history;
// afterwards it lists the last Lookback days of ingest_dt= partitions. A
// pass marks the history incomplete before it loads anything, so a pass that
// stops for any reason, including a crash, leaves the next pass to list the
// whole history again. Reconcile lists the whole history of every feed.
//
// Fixed SQL lives in sql/*.sql. SQL that embeds a feed expression or depends
// on a feed's format is built in load.go.
package ingest

import (
	"context"
	"database/sql"
	"embed"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"
)

//go:embed sql/*.sql
var sqlFS embed.FS

// query returns the embedded statement sql/<name>.sql.
func query(name string) string {
	b, err := sqlFS.ReadFile("sql/" + name + ".sql")
	if err != nil {
		panic(err)
	}
	return string(b)
}

// Options configures Run.
type Options struct {
	// Raw is the raw root: gs://<bucket>/raw or a local directory.
	Raw string
	// Reconcile lists every feed's whole history.
	Reconcile bool
	// Accept holds quarantined batch IDs to release by hand.
	Accept []string
	// Now sets the current time for discovery. Zero means time.Now().
	Now time.Time
	// Lookback is the number of days before today that discovery lists for
	// a feed whose history is complete. Zero means 7.
	Lookback int
}

// Report is the outcome of one Run.
type Report struct {
	// Batches holds one Result per batch decided, in feed and run order.
	Batches []Result
	// Skipped holds the feeds that stopped on an error this pass. Each one
	// retries on the next pass.
	Skipped []Skip
}

// Result describes one decided batch.
type Result struct {
	Batch   string
	Feed    string
	Status  string // accepted, quarantined, rejected, or superseded
	Records int64
	Rejects int64
	Reason  string
}

// Skip names a feed that stopped on an error.
type Skip struct {
	Feed string
	Err  error
}

// feed is one feed_manifest row.
type feed struct {
	ID         string
	Kind       string
	Format     string
	RecordPath sql.NullString
	Identity   string
	ValidFrom  string
	Scope      sql.NullString
	Scopes     sql.NullString
	Required   []string
	MaxDropPct sql.NullFloat64
}

func (f feed) scoped() bool { return f.Scope.Valid }

// batch is one raw/ batch.
type batch struct {
	ID       string // <feed>/ingest_dt=<date>/run=<time>
	Feed     string
	IngestDT time.Time
	Run      time.Time
}

const runLayout = "20060102T150405Z"

type loader struct {
	conn     *sql.Conn
	raw      string
	now      time.Time
	lookback int
}

// Run loads every new batch. A feed that hits an error other than malformed
// input stops for this pass and is reported in Report.Skipped; the other
// feeds continue. Run returns an error only when it cannot start.
func Run(ctx context.Context, d *sql.DB, opts Options) (Report, error) {
	if opts.Raw == "" {
		return Report{}, fmt.Errorf("raw root is empty")
	}
	l := &loader{raw: strings.TrimSuffix(opts.Raw, "/"), now: opts.Now, lookback: opts.Lookback}
	if l.now.IsZero() {
		l.now = time.Now()
	}
	if l.lookback == 0 {
		l.lookback = 7
	}

	conn, err := d.Conn(ctx)
	if err != nil {
		return Report{}, err
	}
	defer conn.Close()
	l.conn = conn

	feeds, err := l.feeds(ctx)
	if err != nil {
		return Report{}, err
	}
	if err := l.inTx(ctx, stmt{q: query("stale_by_manifest")}, stmt{q: query("purge")}); err != nil {
		return Report{}, err
	}

	accepted := map[string]bool{}
	for _, id := range opts.Accept {
		b, err := parseBatchID(id)
		if err != nil {
			return Report{}, err
		}
		if _, ok := feeds[b.Feed]; !ok {
			return Report{}, fmt.Errorf("accept %s: feed %q is not declared", id, b.Feed)
		}
		if _, err := conn.ExecContext(ctx, query("accept_insert"), id); err != nil {
			return Report{}, err
		}
		accepted[b.Feed] = true
	}

	ids := make([]string, 0, len(feeds))
	for id := range feeds {
		ids = append(ids, id)
	}
	sort.Strings(ids)

	var rep Report
	for _, id := range ids {
		rs, err := l.runFeed(ctx, feeds[id], opts.Reconcile, accepted[id])
		rep.Batches = append(rep.Batches, rs...)
		if err != nil {
			rep.Skipped = append(rep.Skipped, Skip{Feed: id, Err: err})
		}
	}
	return rep, nil
}

// runFeed discovers and loads one feed's new batches. It rebuilds the feed
// when a batch of the feed was accepted by hand, or when a snapshot batch
// arrives older than one already decided, because SCD history and the drop
// gate both depend on run order.
func (l *loader) runFeed(ctx context.Context, f feed, reconcile, rebuild bool) ([]Result, error) {
	var complete bool
	if err := l.conn.QueryRowContext(ctx, query("history_get"), f.ID).Scan(&complete); err != nil {
		return nil, err
	}
	full := reconcile || !complete || rebuild
	found, err := l.discover(ctx, f.ID, full)
	if err != nil {
		return nil, err
	}
	loaded, err := l.ledgerBatches(ctx, f.ID)
	if err != nil {
		return nil, err
	}

	if !rebuild && f.Kind == "snapshot" {
		var newest time.Time
		for _, b := range loaded {
			if b.Run.After(newest) {
				newest = b.Run
			}
		}
		for _, b := range found {
			_, done := loaded[b.ID]
			rebuild = rebuild || (!done && b.Run.Before(newest))
		}
	}
	if rebuild {
		if err := l.inTx(ctx, stmt{query("stale_feed"), []any{f.ID}}, stmt{q: query("purge")}); err != nil {
			return nil, err
		}
		loaded = nil
		complete = false // purge.sql recreated the state row as incomplete
		if !full {
			if found, err = l.discover(ctx, f.ID, true); err != nil {
				return nil, err
			}
		}
	}

	var todo []batch
	for _, b := range found {
		if _, done := loaded[b.ID]; !done {
			todo = append(todo, b)
		}
	}
	sortBatches(todo)
	if len(todo) > 0 && complete {
		if err := l.setComplete(ctx, f.ID, false); err != nil {
			return nil, err
		}
		complete = false
	}
	load := l.loadAll
	if f.Kind == "latest" {
		load = l.loadLatest
	}
	out, err := load(ctx, f, todo)
	if err != nil {
		return out, err
	}
	if !complete {
		return out, l.setComplete(ctx, f.ID, true)
	}
	return out, nil
}

// loadAll loads every batch in run order.
func (l *loader) loadAll(ctx context.Context, f feed, todo []batch) ([]Result, error) {
	var out []Result
	for _, b := range todo {
		r, err := l.load(ctx, f, b)
		if err != nil {
			return out, err
		}
		out = append(out, r)
	}
	return out, nil
}

// loadLatest loads only the newest new batch of a latest feed, and an older
// one only when every newer one is rejected. Every other new batch, and any
// batch not newer than the last accepted one, is recorded as superseded
// without being read.
func (l *loader) loadLatest(ctx context.Context, f feed, todo []batch) ([]Result, error) {
	var records int64
	var lastRun time.Time
	err := l.conn.QueryRowContext(ctx, query("gate_last_accepted"), f.ID).Scan(&records, &lastRun)
	if err != nil && err != sql.ErrNoRows {
		return nil, err
	}

	results := map[string]Result{}
	first := len(todo) // todo[first:] went through load
	for i := len(todo) - 1; i >= 0 && todo[i].Run.After(lastRun); i-- {
		r, err := l.load(ctx, f, todo[i])
		if err != nil {
			return nil, err
		}
		results[r.Batch] = r
		first = i
		if r.Status != "rejected" {
			break
		}
	}
	for _, b := range todo[:first] {
		r := Result{Batch: b.ID, Feed: f.ID, Status: "superseded", Reason: "a newer batch of this latest feed was decided"}
		if _, err := l.conn.ExecContext(ctx, query("ledger_insert"), ledgerArgs(b, r)...); err != nil {
			return nil, err
		}
		results[r.Batch] = r
	}

	out := make([]Result, 0, len(results))
	for _, b := range todo {
		if r, ok := results[b.ID]; ok {
			out = append(out, r)
		}
	}
	return out, nil
}

func (l *loader) setComplete(ctx context.Context, feedID string, c bool) error {
	_, err := l.conn.ExecContext(ctx, query("history_set"), feedID, c)
	return err
}

func (l *loader) inTx(ctx context.Context, stmts ...stmt) error {
	tx, err := l.conn.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, s := range stmts {
		if _, err := tx.ExecContext(ctx, s.q, s.args...); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (l *loader) feeds(ctx context.Context) (map[string]feed, error) {
	rows, err := l.conn.QueryContext(ctx, query("feeds"))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]feed{}
	for rows.Next() {
		var f feed
		var req string
		if err := rows.Scan(&f.ID, &f.Kind, &f.Format, &f.RecordPath, &f.Identity, &f.ValidFrom,
			&f.Scope, &f.Scopes, &req, &f.MaxDropPct); err != nil {
			return nil, err
		}
		if err := json.Unmarshal([]byte(req), &f.Required); err != nil {
			return nil, fmt.Errorf("feed %s: required: %w", f.ID, err)
		}
		out[f.ID] = f
	}
	return out, rows.Err()
}

// ledgerBatches returns the IDs of the batches of a feed that the ledger
// holds, with their parsed run times.
func (l *loader) ledgerBatches(ctx context.Context, feedID string) (map[string]batch, error) {
	rows, err := l.conn.QueryContext(ctx, query("ledger_batches"), feedID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]batch{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		b, err := parseBatchID(id)
		if err != nil {
			return nil, err
		}
		out[id] = b
	}
	return out, rows.Err()
}

// discover lists _SUCCESS markers for a feed, either across its whole
// history or for today and the lookback days before it.
func (l *loader) discover(ctx context.Context, feedID string, full bool) ([]batch, error) {
	prefix := l.raw + "/" + feedID + "/"
	var patterns []string
	if full {
		patterns = []string{prefix + "ingest_dt=*/run=*/_SUCCESS"}
	} else {
		day := l.now.UTC()
		for i := 0; i <= l.lookback; i++ {
			patterns = append(patterns, prefix+"ingest_dt="+day.AddDate(0, 0, -i).Format("2006-01-02")+"/run=*/_SUCCESS")
		}
	}

	var out []batch
	for _, p := range patterns {
		bs, err := l.glob(ctx, feedID, p)
		if err != nil {
			return nil, err
		}
		out = append(out, bs...)
	}
	return out, nil
}

func (l *loader) glob(ctx context.Context, feedID, pattern string) ([]batch, error) {
	rows, err := l.conn.QueryContext(ctx, query("glob"), pattern)
	if err != nil {
		return nil, fmt.Errorf("list %s: %w", pattern, err)
	}
	defer rows.Close()
	var out []batch
	for rows.Next() {
		var file string
		if err := rows.Scan(&file); err != nil {
			return nil, err
		}
		i := strings.LastIndex(file, "/"+feedID+"/ingest_dt=")
		if i < 0 {
			return nil, fmt.Errorf("unexpected marker path %s", file)
		}
		b, err := parseBatchID(strings.TrimSuffix(file[i+1:], "/_SUCCESS"))
		if err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

func parseBatchID(id string) (batch, error) {
	parts := strings.Split(id, "/")
	if len(parts) != 3 || !strings.HasPrefix(parts[1], "ingest_dt=") || !strings.HasPrefix(parts[2], "run=") {
		return batch{}, fmt.Errorf("batch ID %q is not <feed>/ingest_dt=<date>/run=<time>", id)
	}
	dt, err := time.Parse("2006-01-02", strings.TrimPrefix(parts[1], "ingest_dt="))
	if err != nil {
		return batch{}, fmt.Errorf("batch ID %q: %w", id, err)
	}
	run, err := time.Parse(runLayout, strings.TrimPrefix(parts[2], "run="))
	if err != nil {
		return batch{}, fmt.Errorf("batch ID %q: %w", id, err)
	}
	return batch{ID: id, Feed: parts[0], IngestDT: dt, Run: run}, nil
}

func sortBatches(bs []batch) {
	sort.Slice(bs, func(i, j int) bool {
		if !bs[i].Run.Equal(bs[j].Run) {
			return bs[i].Run.Before(bs[j].Run)
		}
		return bs[i].ID < bs[j].ID
	})
}
