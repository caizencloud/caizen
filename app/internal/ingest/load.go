package ingest

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/duckdb/duckdb-go/v2"

	"github.com/caizencloud/caizen/app/internal/db"
)

// inputError marks a failure to read a batch's own files, as opposed to a
// failure in a feed expression or in the loader.
type inputError struct{ err error }

func (e *inputError) Error() string { return e.err.Error() }
func (e *inputError) Unwrap() error { return e.err }

// load reads, validates, and commits one batch in one transaction.
//
//  1. READ: _meta.json, then the objects it lists, into _raw.
//  2. SHRED: evaluate the feed's expressions into _staged.
//  3. VALIDATE: a failed required expression rejects the batch. Other
//     failures and conflicting duplicates reject single records. An
//     unscoped snapshot or latest batch that shrank past max_drop_pct is
//     quarantined.
//  4. COMMIT: snapshot SCD merge, event append, or latest replace, then the
//     ledger row.
//
// A batch whose files are malformed (DuckDB Invalid Input or Conversion
// errors during READ) is rejected. Any other error is returned for the
// caller to retry on a later pass, because rejecting a batch by mistake
// loses its data for good.
func (l *loader) load(ctx context.Context, f feed, b batch) (Result, error) {
	res, err := l.loadTx(ctx, f, b)
	if err == nil {
		return res, nil
	}
	var ie *inputError
	var de *duckdb.Error
	if !errors.As(err, &ie) || !errors.As(err, &de) ||
		(de.Type != duckdb.ErrorTypeInvalidInput && de.Type != duckdb.ErrorTypeConversion) {
		return Result{}, fmt.Errorf("batch %s: %w", b.ID, err)
	}
	// The failed transaction is aborted, so the rejection gets its own.
	res = Result{Batch: b.ID, Feed: f.ID, Status: "rejected", Reason: "malformed input: " + de.Msg}
	if _, err := l.conn.ExecContext(ctx, query("ledger_insert"), ledgerArgs(b, res)...); err != nil {
		return Result{}, err
	}
	return res, nil
}

func (l *loader) loadTx(ctx context.Context, f feed, b batch) (Result, error) {
	tx, err := l.conn.BeginTx(ctx, nil)
	if err != nil {
		return Result{}, err
	}
	defer tx.Rollback()

	s := &step{ctx: ctx, tx: tx, f: f, b: b}
	res, err := s.run(l.raw)
	if err != nil {
		return Result{}, err
	}
	stmts := []stmt{{query("ledger_insert"), ledgerArgs(b, res)}}
	for _, t := range []string{"_meta", "_raw", "_staged", "_checked", "_covered", "_s", "_eff"} {
		stmts = append(stmts, stmt{q: "DROP TABLE IF EXISTS " + t})
	}
	if err := s.execAll(stmts...); err != nil {
		return Result{}, err
	}
	return res, tx.Commit()
}

func ledgerArgs(b batch, r Result) []any {
	var reason any
	if r.Reason != "" {
		reason = r.Reason
	}
	return []any{b.ID, b.Feed, b.IngestDT.Format("2006-01-02"), b.Run, r.Status, r.Records, r.Rejects, reason}
}

// stmt is one SQL statement and its arguments.
type stmt struct {
	q    string
	args []any
}

// step holds the state of one batch load.
type step struct {
	ctx context.Context
	tx  *sql.Tx
	f   feed
	b   batch
}

func (s *step) execAll(stmts ...stmt) error {
	for _, st := range stmts {
		if _, err := s.tx.ExecContext(s.ctx, st.q, st.args...); err != nil {
			return fmt.Errorf("%w\nSQL: %s", err, st.q)
		}
	}
	return nil
}

func (s *step) row(q string, args []any, dest ...any) error {
	return s.tx.QueryRowContext(s.ctx, q, args...).Scan(dest...)
}

func (s *step) result(status, reason string, records, rejects int64) Result {
	return Result{Batch: s.b.ID, Feed: s.f.ID, Status: status, Records: records, Rejects: rejects, Reason: reason}
}

func (s *step) run(raw string) (Result, error) {
	// 1. READ
	files, reason, err := s.readMeta(raw)
	if err != nil {
		return Result{}, &inputError{err}
	}
	if reason != "" {
		return s.result("rejected", reason, 0, 0), nil
	}
	if err := s.read(files); err != nil {
		return Result{}, &inputError{err}
	}

	// 2. SHRED
	if err := s.shred(); err != nil {
		return Result{}, err
	}

	// 3. VALIDATE
	var missing, seen int64
	if err := s.row(query("required_counts"), nil, &missing, &seen); err != nil {
		return Result{}, err
	}
	if missing > 0 {
		if err := s.execAll(stmt{query("required_rejects"), []any{s.b.ID, s.f.ID}}); err != nil {
			return Result{}, err
		}
		return s.result("rejected", fmt.Sprintf("%d records missing a required foreign ID", missing), seen, missing), nil
	}
	records, rejects, err := s.check()
	if err != nil {
		return Result{}, err
	}
	var note string
	if s.f.Kind != "event" && !s.f.scoped() && s.f.MaxDropPct.Valid {
		reason, ok, err := s.gate(records)
		if err != nil {
			return Result{}, err
		}
		if !ok {
			return s.result("quarantined", reason, records, rejects), nil
		}
		note = reason
	}

	// 4. COMMIT
	if err := s.commit(); err != nil {
		return Result{}, err
	}
	return s.result("accepted", note, records, rejects), nil
}

// readMeta loads _meta.json and returns the local or gs:// paths of the
// objects it lists. A non-empty reason rejects the batch.
func (s *step) readMeta(raw string) ([]string, string, error) {
	if err := s.execAll(stmt{query("meta"), []any{raw + "/" + s.b.ID + "/_meta.json"}}); err != nil {
		return nil, "", err
	}
	var n int
	var listed bool
	if err := s.row(query("meta_status"), nil, &n, &listed); err != nil {
		return nil, "", err
	}
	if n == 0 {
		return nil, "_meta.json is missing", nil
	}
	if !listed {
		return nil, "_meta.json objects is missing or not a list", nil
	}

	rows, err := s.tx.QueryContext(s.ctx, query("meta_objects"))
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()
	var files []string
	for rows.Next() {
		var uri string
		if err := rows.Scan(&uri); err != nil {
			return nil, "", err
		}
		// Collectors list objects as gs://<bucket>/raw/<batch>/... Resolve
		// them against the raw root, so a local copy of raw/ reads the same.
		i := strings.Index(uri, "/raw/")
		if i < 0 || !strings.HasPrefix(uri[i+len("/raw/"):], s.b.ID+"/") {
			return nil, fmt.Sprintf("object %s is outside the batch", uri), nil
		}
		files = append(files, raw+"/"+uri[i+len("/raw/"):])
	}
	return files, "", rows.Err()
}

// read loads the batch's records into _raw(json, obj). The reader depends
// on the feed's format, and record_path wraps it, so this SQL is built here.
func (s *step) read(files []string) error {
	if len(files) == 0 {
		return s.execAll(stmt{q: `CREATE OR REPLACE TEMP TABLE _raw (json JSON, obj STRUCT(filename VARCHAR))`})
	}
	quoted := make([]string, len(files))
	for i, f := range files {
		quoted[i] = db.Quote(f)
	}
	list := "[" + strings.Join(quoted, ", ") + "]"

	var src string
	switch s.f.Format {
	case "ndjson":
		src = fmt.Sprintf(`SELECT json, {'filename': filename} AS obj
			FROM read_ndjson_objects(%s, filename = true, hive_partitioning = false)`, list)
	case "json":
		src = fmt.Sprintf(`SELECT json, {'filename': filename} AS obj
			FROM read_json_objects(%s, format = 'unstructured', filename = true, hive_partitioning = false)`, list)
	case "csv":
		src = fmt.Sprintf(`SELECT json_merge_patch(to_json(t), '{"filename":null}')::JSON AS json,
			       {'filename': t.filename} AS obj
			FROM read_csv(%s, comment = '#', header = true, all_varchar = true,
			              filename = true, hive_partitioning = false) t`, list)
	default:
		return fmt.Errorf("unknown format %q", s.f.Format)
	}
	if s.f.RecordPath.Valid {
		src = fmt.Sprintf(`SELECT unnest(json_extract(json, %s)) AS json, obj FROM (%s)`,
			db.Quote(s.f.RecordPath.String), src)
	}
	return s.execAll(stmt{q: `CREATE OR REPLACE TEMP TABLE _raw AS ` + src})
}

// shred evaluates the feed's expressions into _staged. The expressions are
// pack SQL, so this statement is built here.
func (s *step) shred() error {
	scope := "NULL"
	if s.f.scoped() {
		scope = "(" + s.f.Scope.String + ")"
	}
	missing := "NULL"
	if len(s.f.Required) > 0 {
		var whens []string
		for _, r := range s.f.Required {
			whens = append(whens, fmt.Sprintf("WHEN (%s) IS NULL THEN %s", r, db.Quote(r)))
		}
		missing = "CASE " + strings.Join(whens, " ") + " END"
	}
	return s.execAll(stmt{q: fmt.Sprintf(`CREATE OR REPLACE TEMP TABLE _staged AS
		SELECT json AS data,
		       json::VARCHAR AS line,
		       md5(json::VARCHAR) AS data_hash,
		       CAST((%s) AS VARCHAR) AS record_id,
		       CAST(TRY_CAST((%s) AS TIMESTAMPTZ) AS TIMESTAMP) AS valid_from,
		       CAST(%s AS VARCHAR) AS scope,
		       %s AS missing
		FROM _raw, _meta`, s.f.Identity, s.f.ValidFrom, scope, missing)})
}

// check builds _covered for a scoped feed, rejects single bad records and conflicting
// duplicates, and builds _s with one row per valid record_id. It returns
// the number of distinct record IDs in the batch and the number of
// rejected lines.
func (s *step) check() (int64, int64, error) {
	var stmts []stmt
	if s.f.scoped() {
		// The scopes expression is pack SQL, so this statement is built here.
		stmts = append(stmts, stmt{q: fmt.Sprintf(`CREATE OR REPLACE TEMP TABLE _covered AS
			SELECT DISTINCT CAST(unnest(%s) AS VARCHAR) AS scope FROM _meta`, s.f.Scopes.String)})
	}
	if err := s.execAll(append(stmts,
		stmt{query("check_reasons"), []any{s.f.scoped()}},
		stmt{q: query("check_duplicates")},
		stmt{query("check_rejects"), []any{s.b.ID, s.f.ID}},
		stmt{q: query("check_valid")},
	)...); err != nil {
		return 0, 0, err
	}
	var records, rejects int64
	err := s.row(query("check_counts"), nil, &records, &rejects)
	return records, rejects, err
}

// gate applies the drop check to an unscoped snapshot or a latest batch. It returns ok=false
// to quarantine. A non-empty reason with ok=true explains an accept that
// overrode the check.
func (s *step) gate(records int64) (string, bool, error) {
	var base int64
	var baseRun time.Time
	err := s.row(query("gate_last_accepted"), []any{s.f.ID}, &base, &baseRun)
	if err == sql.ErrNoRows {
		return "", true, nil
	}
	if err != nil {
		return "", false, err
	}
	pct := s.f.MaxDropPct.Float64
	if float64(records) >= float64(base)*(1-pct/100) {
		return "", true, nil
	}

	var manual int
	if err := s.row(query("gate_manual"), []any{s.b.ID}, &manual); err != nil {
		return "", false, err
	}
	if manual > 0 {
		return "accepted by operator", true, nil
	}

	// A later snapshot that agrees with a quarantined one confirms that the
	// estate really shrank.
	var qID string
	var q int64
	err = s.row(query("gate_quarantined_since"), []any{s.f.ID, baseRun}, &qID, &q)
	if err != nil && err != sql.ErrNoRows {
		return "", false, err
	}
	if err == nil && abs(records-q) <= int64(float64(q)*pct/100) {
		return "confirms quarantined batch " + qID, true, nil
	}
	return fmt.Sprintf("%d records is more than %.0f%% below the last accepted batch's %d", records, pct, base), false, nil
}

// commit merges _s into record. The rules are in sql/event_*.sql,
// sql/latest_*.sql, and sql/snapshot_*.sql.
func (s *step) commit() error {
	switch s.f.Kind {
	case "event":
		return s.execAll(
			stmt{query("event_move"), []any{s.f.ID, s.b.ID, s.b.Run}},
			stmt{query("event_insert"), []any{s.f.ID, s.b.ID}},
		)
	case "latest":
		return s.execAll(
			stmt{query("latest_clear"), []any{s.f.ID}},
			stmt{query("latest_insert"), []any{s.f.ID, s.b.ID}},
		)
	}
	absent := stmt{query("snapshot_absent"), []any{s.f.ID, s.b.Run}}
	if s.f.scoped() {
		absent.q = query("snapshot_absent_scoped")
	}
	return s.execAll(
		stmt{query("snapshot_eff"), []any{s.f.ID, s.b.Run}},
		stmt{query("snapshot_changed"), []any{s.f.ID}},
		absent,
		stmt{query("snapshot_insert"), []any{s.f.ID, s.b.ID}},
	)
}

func abs(n int64) int64 {
	if n < 0 {
		return -n
	}
	return n
}
