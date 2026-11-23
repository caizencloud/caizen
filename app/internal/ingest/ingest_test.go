package ingest

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/caizencloud/caizen/app/internal/db"
)

// Each test builds a small raw/ tree in a temp directory and states its
// expected rows from the ingest rules, not from running the loader.

const (
	snapFeed = `INSERT INTO feed_manifest
		(feed_id, pack_id, kind, format, identity, valid_from, required, max_drop_pct, provenance)
		VALUES ('snap', 'test', 'snapshot', 'ndjson', $$json->>'$.id'$$,
		        $$COALESCE(json->>'$.t', meta->>'$.read_time')$$, [], 25, 'config')`
	eventFeed = `INSERT INTO feed_manifest
		(feed_id, pack_id, kind, format, identity, valid_from, required, provenance)
		VALUES ('ev', 'test', 'event', 'ndjson', $$json->>'$.id'$$, $$meta->>'$.read_time'$$, [], 'config')`
	scopedFeed = `INSERT INTO feed_manifest
		(feed_id, pack_id, kind, format, identity, valid_from, scope, scopes, required, provenance)
		VALUES ('aa', 'test', 'snapshot', 'ndjson', $$json->>'$.id'$$, $$meta->>'$.read_time'$$,
		        $$json->>'$.img'$$,
		        $$list_filter(json_keys(meta->'$.statuses'), lambda k: json_extract_string(meta->'$.statuses', '$."' || k || '".status') = 'ok')$$,
		        [], 'config')`
	requiredFeed = `INSERT INTO feed_manifest
		(feed_id, pack_id, kind, format, identity, valid_from, required, max_drop_pct, provenance)
		VALUES ('req', 'test', 'snapshot', 'ndjson', $$json->>'$.id'$$, $$meta->>'$.read_time'$$,
		        [$$json->>'$.ref'$$], 25, 'config')`
)

type fixture struct {
	t   *testing.T
	d   *db.DB
	raw string
}

func newFixture(t *testing.T, feeds ...string) *fixture {
	t.Helper()
	d, err := db.Open(context.Background(), db.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { d.Close() })
	for _, f := range feeds {
		if _, err := d.Exec(f); err != nil {
			t.Fatal(err)
		}
	}
	return &fixture{t: t, d: d, raw: t.TempDir()}
}

// batch writes one batch. run is YYYYMMDDTHHMMSSZ; ingest_dt is its date.
// meta gains read_time (the run as RFC 3339) and the objects list.
func (f *fixture) batch(feed, run string, meta map[string]any, lines ...string) string {
	f.t.Helper()
	at, err := time.Parse(runLayout, run)
	if err != nil {
		f.t.Fatal(err)
	}
	id := feed + "/ingest_dt=" + at.Format("2006-01-02") + "/run=" + run
	dir := filepath.Join(f.raw, filepath.FromSlash(id))
	if err := os.MkdirAll(filepath.Join(dir, "data"), 0o755); err != nil {
		f.t.Fatal(err)
	}
	if meta == nil {
		meta = map[string]any{}
	}
	meta["read_time"] = at.Format(time.RFC3339)
	meta["objects"] = []string{}
	if len(lines) > 0 {
		body := strings.Join(lines, "\n") + "\n"
		if err := os.WriteFile(filepath.Join(dir, "data", "part-0.ndjson"), []byte(body), 0o644); err != nil {
			f.t.Fatal(err)
		}
		meta["objects"] = []string{"gs://bucket/raw/" + id + "/data/part-0.ndjson"}
	}
	m, _ := json.Marshal(meta)
	for name, body := range map[string][]byte{"_meta.json": m, "_SUCCESS": nil} {
		if err := os.WriteFile(filepath.Join(dir, name), body, 0o644); err != nil {
			f.t.Fatal(err)
		}
	}
	return id
}

// run runs one pass and returns its decided batches. The fixture's clock is
// 2026-11-25, so the 7-day window starts at 2026-11-18.
func (f *fixture) run(opts Options) []Result {
	f.t.Helper()
	return f.report(opts).Batches
}

func (f *fixture) report(opts Options) Report {
	f.t.Helper()
	opts.Raw = f.raw
	if opts.Now.IsZero() {
		opts.Now = time.Date(2026, 11, 25, 0, 0, 0, 0, time.UTC)
	}
	rep, err := Run(context.Background(), f.d.DB, opts)
	if err != nil {
		f.t.Fatal(err)
	}
	return rep
}

func skipped(rep Report) []string {
	var out []string
	for _, s := range rep.Skipped {
		out = append(out, s.Feed)
	}
	return out
}

// rows returns a feed's record rows as "id from to reason v".
func (f *fixture) rows(feed string) []string {
	f.t.Helper()
	rs, err := f.d.Query(`SELECT record_id || ' ' || strftime(valid_from, '%m-%d %H:%M') || ' ' ||
		coalesce(strftime(valid_to, '%m-%d %H:%M'), '-') || ' ' || coalesce(end_reason, '-') || ' ' ||
		coalesce(data->>'$.v', '-')
		FROM record WHERE feed_id = ? ORDER BY record_id, valid_from, valid_to`, feed)
	if err != nil {
		f.t.Fatal(err)
	}
	defer rs.Close()
	var out []string
	for rs.Next() {
		var s string
		if err := rs.Scan(&s); err != nil {
			f.t.Fatal(err)
		}
		out = append(out, s)
	}
	return out
}

func (f *fixture) count(q string, args ...any) int {
	f.t.Helper()
	var n int
	if err := f.d.QueryRow(q, args...).Scan(&n); err != nil {
		f.t.Fatal(err)
	}
	return n
}

func want(t *testing.T, got, want []string) {
	t.Helper()
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("rows:\n got  %q\n want %q", got, want)
	}
}

func statuses(rs []Result) []string {
	var out []string
	for _, r := range rs {
		out = append(out, r.Status)
	}
	return out
}

func ids(n int) []string {
	var out []string
	for i := 1; i <= n; i++ {
		out = append(out, `{"id":"r`+string(rune('0'+i))+`","v":1}`)
	}
	return out
}

func TestSnapshotChangeAbsenceAndNew(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, `{"id":"a","v":1}`, `{"id":"b","v":1}`)
	f.batch("snap", "20261121T060000Z", nil, `{"id":"a","v":2}`, `{"id":"c","v":1}`)
	f.run(Options{})
	want(t, f.rows("snap"), []string{
		"a 11-20 06:00 11-21 06:00 changed 1",
		"a 11-21 06:00 - - 2",
		"b 11-20 06:00 11-21 06:00 absent 1",
		"c 11-21 06:00 - - 1",
	})
}

func TestUnchangedSnapshotWritesOnlyLedger(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, `{"id":"a","v":1}`, `{"id":"b","v":1}`)
	f.batch("snap", "20261121T060000Z", nil, `{"id":"b","v":1}`, `{"id":"a","v":1}`)
	f.run(Options{})
	want(t, f.rows("snap"), []string{"a 11-20 06:00 - - 1", "b 11-20 06:00 - - 1"})
	if n := f.count(`SELECT count(*) FROM ledger WHERE status = 'accepted'`); n != 2 {
		t.Fatalf("accepted batches = %d, want 2", n)
	}
}

func TestReappearingRecordOpensNewRow(t *testing.T) {
	// Four unchanged records keep each drop under the 25% gate.
	fill := ids(4)
	with := func(lines ...string) []string { return append(append([]string{}, fill...), lines...) }
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, with(`{"id":"b","v":1}`)...)
	f.batch("snap", "20261121T060000Z", nil, with()...)
	f.batch("snap", "20261122T060000Z", nil, with(`{"id":"b","v":1}`)...)
	want(t, statuses(f.run(Options{})), []string{"accepted", "accepted", "accepted"})
	want(t, f.rows("snap")[:2], []string{
		"b 11-20 06:00 11-21 06:00 absent 1",
		"b 11-22 06:00 - - 1",
	})
}

func TestChangeWithoutNewerValidFromStartsAtBatchTime(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, `{"id":"a","t":"2026-11-01T00:00:00Z","v":1}`)
	f.batch("snap", "20261121T060000Z", nil, `{"id":"a","t":"2026-11-01T00:00:00Z","v":2}`)
	f.run(Options{})
	want(t, f.rows("snap"), []string{
		"a 11-01 00:00 11-21 06:00 changed 1",
		"a 11-21 06:00 - - 2",
	})
}

func TestQuarantineThenConfirm(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, ids(8)...)
	f.batch("snap", "20261121T060000Z", nil, ids(4)...)
	rs := f.run(Options{})
	want(t, statuses(rs), []string{"accepted", "quarantined"})
	if n := f.count(`SELECT count(*) FROM record WHERE valid_to IS NULL`); n != 8 {
		t.Fatalf("open rows after quarantine = %d, want 8", n)
	}

	f.batch("snap", "20261122T060000Z", nil, ids(4)...)
	rs = f.run(Options{})
	want(t, statuses(rs), []string{"accepted"})
	if !strings.HasPrefix(rs[0].Reason, "confirms quarantined batch snap/ingest_dt=2026-11-21") {
		t.Fatalf("reason = %q", rs[0].Reason)
	}
	if n := f.count(`SELECT count(*) FROM record WHERE valid_to IS NULL`); n != 4 {
		t.Fatalf("open rows after confirm = %d, want 4", n)
	}
	if n := f.count(`SELECT count(*) FROM record WHERE end_reason = 'absent' AND valid_to = TIMESTAMP '2026-11-22 06:00:00'`); n != 4 {
		t.Fatalf("rows closed absent at the confirming batch = %d, want 4", n)
	}
}

func TestManualAcceptRebuildsFeed(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, ids(8)...)
	q := f.batch("snap", "20261121T060000Z", nil, ids(4)...)
	want(t, statuses(f.run(Options{})), []string{"accepted", "quarantined"})

	rs := f.run(Options{Accept: []string{q}})
	want(t, statuses(rs), []string{"accepted", "accepted"})
	if rs[1].Reason != "accepted by operator" {
		t.Fatalf("reason = %q", rs[1].Reason)
	}
	if n := f.count(`SELECT count(*) FROM record WHERE valid_to IS NULL`); n != 4 {
		t.Fatalf("open rows = %d, want 4", n)
	}
}

func TestOutOfOrderSnapshotRebuildsInRunOrder(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261121T060000Z", nil, `{"id":"a","v":2}`, `{"id":"b","v":1}`, `{"id":"c","v":1}`)
	f.run(Options{})
	f.batch("snap", "20261120T060000Z", nil, `{"id":"a","v":1}`, `{"id":"b","v":1}`, `{"id":"c","v":1}`)
	rs := f.run(Options{})
	want(t, statuses(rs), []string{"accepted", "accepted"})
	// The same rows as loading 11-20 then 11-21: a changed, b and c unchanged.
	want(t, f.rows("snap"), []string{
		"a 11-20 06:00 11-21 06:00 changed 1",
		"a 11-21 06:00 - - 2",
		"b 11-20 06:00 - - 1",
		"c 11-20 06:00 - - 1",
	})
}

func TestScopedSnapshotClosesOnlyCoveredScopes(t *testing.T) {
	f := newFixture(t, scopedFeed)
	ok := map[string]any{"status": "ok"}
	bad := map[string]any{"status": "error"}
	f.batch("aa", "20261120T060000Z", map[string]any{"statuses": map[string]any{"imgA": ok, "imgB": ok}},
		`{"id":"a1","img":"imgA"}`, `{"id":"a2","img":"imgA"}`, `{"id":"b1","img":"imgB"}`)
	// imgB failed partway: its b2 still loads, but b1 cannot close. imgC is
	// not covered at all: c1 loads.
	f.batch("aa", "20261121T060000Z", map[string]any{"statuses": map[string]any{"imgA": ok, "imgB": bad}},
		`{"id":"a1","img":"imgA"}`, `{"id":"b2","img":"imgB"}`, `{"id":"c1","img":"imgC"}`)
	// imgB covered with no occurrences: b1 and b2 close; imgA and imgC rows stay.
	f.batch("aa", "20261122T060000Z", map[string]any{"statuses": map[string]any{"imgB": ok}})
	f.run(Options{})
	want(t, f.rows("aa"), []string{
		"a1 11-20 06:00 - - -",
		"a2 11-20 06:00 11-21 06:00 absent -",
		"b1 11-20 06:00 11-22 06:00 absent -",
		"b2 11-21 06:00 11-22 06:00 absent -",
		"c1 11-21 06:00 - - -",
	})
	if n := f.count(`SELECT count(*) FROM reject`); n != 0 {
		t.Fatalf("rejects = %d, want 0", n)
	}
}

func TestDuplicateIdentities(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, `{"id":"a","v":1}`, `{"id":"b","v":1}`)
	f.batch("snap", "20261121T060000Z", nil,
		`{"id":"a","v":1}`, `{"id":"a","v":1}`, `{"id":"b","v":2}`, `{"id":"b","v":3}`)
	rs := f.run(Options{})
	if rs[1].Records != 2 || rs[1].Rejects != 2 {
		t.Fatalf("second batch records=%d rejects=%d, want 2 and 2", rs[1].Records, rs[1].Rejects)
	}
	// b's open row stays as it was: a conflicting duplicate is not absence.
	want(t, f.rows("snap"), []string{"a 11-20 06:00 - - 1", "b 11-20 06:00 - - 1"})
}

func TestMissingRequiredRejectsWholeBatch(t *testing.T) {
	f := newFixture(t, requiredFeed)
	f.batch("req", "20261120T060000Z", nil, `{"id":"a","ref":"x"}`, `{"id":"b","ref":"x"}`)
	f.batch("req", "20261121T060000Z", nil, `{"id":"a","ref":"x"}`, `{"id":"c"}`)
	// A JSON null is as missing as an absent key.
	f.batch("req", "20261122T060000Z", nil, `{"id":"a","ref":"x"}`, `{"id":"b","ref":null}`)
	rs := f.run(Options{})
	want(t, statuses(rs), []string{"accepted", "rejected", "rejected"})
	want(t, f.rows("req"), []string{"a 11-20 06:00 - - -", "b 11-20 06:00 - - -"})
	if n := f.count(`SELECT count(*) FROM reject WHERE reason LIKE 'missing required foreign ID%'`); n != 2 {
		t.Fatalf("required rejects = %d, want 2", n)
	}
}

func TestSingleBadRecordsAreRejected(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, `{"v":1}`, `{"id":"a","t":"not a time"}`, `{"id":"b","v":1}`)
	rs := f.run(Options{})
	want(t, statuses(rs), []string{"accepted"})
	if rs[0].Records != 2 || rs[0].Rejects != 2 {
		t.Fatalf("records=%d rejects=%d, want 2 and 2", rs[0].Records, rs[0].Rejects)
	}
	want(t, f.rows("snap"), []string{"b 11-20 06:00 - - 1"})
}

func TestEventsAppendOnlyNewContent(t *testing.T) {
	f := newFixture(t, eventFeed)
	f.batch("ev", "20261120T060000Z", nil, `{"id":"e1","v":1}`, `{"id":"e2","v":1}`)
	f.batch("ev", "20261121T060000Z", nil, `{"id":"e1","v":1}`, `{"id":"e2","v":2}`)
	f.run(Options{})
	want(t, f.rows("ev"), []string{
		"e1 11-20 06:00 - - 1",
		"e2 11-20 06:00 - - 1",
		"e2 11-21 06:00 - - 2",
	})
}

func TestChangedManifestRebuildsFeed(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, `{"id":"a","v":1}`)
	f.run(Options{})
	if _, err := f.d.Exec(`UPDATE feed_manifest SET identity = $$upper(json->>'$.id')$$`); err != nil {
		t.Fatal(err)
	}
	rs := f.run(Options{})
	want(t, statuses(rs), []string{"accepted"})
	want(t, f.rows("snap"), []string{"A 11-20 06:00 - - 1"})
}

func TestDiscoveryLooksBackSevenDays(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261101T060000Z", nil, `{"id":"a","v":1}`)
	f.run(Options{}) // new feed: whole history
	f.batch("snap", "20261102T060000Z", nil, `{"id":"a","v":2}`)
	if rs := f.run(Options{}); len(rs) != 0 {
		t.Fatalf("batch 23 days old was found without -reconcile: %v", rs)
	}
	if rs := f.run(Options{Reconcile: true}); len(rs) != 1 {
		t.Fatalf("reconcile found %d batches, want 1", len(rs))
	}
	f.batch("snap", "20261118T060000Z", nil, `{"id":"a","v":3}`)
	if rs := f.run(Options{}); len(rs) != 1 {
		t.Fatalf("batch 7 days old: found %d, want 1", len(rs))
	}
}

func TestQuarantineNotConfirmedThenRecovered(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, ids(8)...)
	f.batch("snap", "20261121T060000Z", nil, ids(4)...)
	// 2 is more than 25% away from the quarantined 4, so it confirms nothing.
	f.batch("snap", "20261122T060000Z", nil, ids(2)...)
	// 8 is back within 25% of the last accepted 8.
	f.batch("snap", "20261123T060000Z", nil, ids(8)...)
	want(t, statuses(f.run(Options{})), []string{"accepted", "quarantined", "quarantined", "accepted"})
	if n := f.count(`SELECT count(*) FROM record WHERE valid_to IS NULL`); n != 8 {
		t.Fatalf("open rows = %d, want 8", n)
	}
	if n := f.count(`SELECT count(*) FROM record`); n != 8 {
		t.Fatalf("rows = %d, want 8: quarantined batches must not change records", n)
	}
}

func TestPartialHistoryResumesWithFullListing(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261101T060000Z", nil, `{"id":"a","v":1}`)
	f.batch("snap", "20261102T060000Z", nil, `{"id":"a","v":2}`)
	f.batch("snap", "20261103T060000Z", nil, `{"id":"a","v":3}`)
	part := filepath.Join(f.raw, "snap", "ingest_dt=2026-11-02", "run=20261102T060000Z", "data", "part-0.ndjson")
	body, err := os.ReadFile(part)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(part); err != nil {
		t.Fatal(err)
	}
	// A listed object that cannot be read is an IO error: the feed stops
	// for this pass with history still incomplete.
	rep := f.report(Options{})
	want(t, statuses(rep.Batches), []string{"accepted"})
	want(t, skipped(rep), []string{"snap"})
	if n := f.count(`SELECT count(*) FROM feed_state WHERE NOT history_complete`); n != 1 {
		t.Fatal("history is still marked complete after a failed pass")
	}

	if err := os.WriteFile(part, body, 0o644); err != nil {
		t.Fatal(err)
	}
	// The batches are 22 days old, outside the 7-day window, and still load.
	want(t, statuses(f.run(Options{})), []string{"accepted", "accepted"})
	want(t, f.rows("snap"), []string{
		"a 11-01 06:00 11-02 06:00 changed 1",
		"a 11-02 06:00 11-03 06:00 changed 2",
		"a 11-03 06:00 - - 3",
	})

	// History is now complete, so an old batch is outside discovery.
	f.batch("snap", "20261104T060000Z", nil, `{"id":"a","v":4}`)
	if rs := f.run(Options{}); len(rs) != 0 {
		t.Fatalf("complete history listed an old partition: %v", rs)
	}
}

func TestMalformedBatchIsRejectedAndFeedContinues(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, `{"id":"a","v":1}`, `{"id":`)
	f.batch("snap", "20261121T060000Z", nil, `{"id":"a","v":2}`)
	rs := f.run(Options{})
	want(t, statuses(rs), []string{"rejected", "accepted"})
	if !strings.HasPrefix(rs[0].Reason, "malformed input: ") {
		t.Fatalf("reason = %q", rs[0].Reason)
	}
	want(t, f.rows("snap"), []string{"a 11-21 06:00 - - 2"})
	// A rejected batch is decided, so the next pass does not retry it.
	if rs := f.run(Options{}); len(rs) != 0 {
		t.Fatalf("next pass decided %v", rs)
	}
}

func TestMissingMetaIsRejected(t *testing.T) {
	f := newFixture(t, snapFeed)
	id := f.batch("snap", "20261120T060000Z", nil, `{"id":"a","v":1}`)
	if err := os.Remove(filepath.Join(f.raw, filepath.FromSlash(id), "_meta.json")); err != nil {
		t.Fatal(err)
	}
	rs := f.run(Options{})
	want(t, statuses(rs), []string{"rejected"})
	if rs[0].Reason != "_meta.json is missing" {
		t.Fatalf("reason = %q", rs[0].Reason)
	}
}

func TestSkippedFeedDoesNotBlockOthers(t *testing.T) {
	f := newFixture(t, snapFeed, eventFeed)
	f.batch("ev", "20261120T060000Z", nil, `{"id":"e1","v":1}`)
	id := f.batch("snap", "20261120T060000Z", nil, `{"id":"a","v":1}`)
	if err := os.Remove(filepath.Join(f.raw, filepath.FromSlash(id), "data", "part-0.ndjson")); err != nil {
		t.Fatal(err)
	}
	rep := f.report(Options{})
	want(t, statuses(rep.Batches), []string{"accepted"})
	if rep.Batches[0].Feed != "ev" {
		t.Fatalf("batches = %v", rep.Batches)
	}
	want(t, skipped(rep), []string{"snap"})
}

func TestLateEventMovesToEarliestRun(t *testing.T) {
	f := newFixture(t, eventFeed)
	f.batch("ev", "20261121T060000Z", nil, `{"id":"e1","v":1}`)
	f.run(Options{})
	early := f.batch("ev", "20261120T060000Z", nil, `{"id":"e1","v":1}`)
	f.run(Options{})
	want(t, f.rows("ev"), []string{"e1 11-20 06:00 - - 1"})
	if n := f.count(`SELECT count(*) FROM record WHERE batch_id = ?`, early); n != 1 {
		t.Fatalf("row is not owned by the earliest batch %s", early)
	}
}

func TestFailedRebuildResumesWithFullListing(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, `{"id":"a","v":2}`)
	f.batch("snap", "20261121T060000Z", nil, `{"id":"a","v":3}`)
	f.run(Options{})
	// An older batch forces a rebuild, and it cannot be read.
	id := f.batch("snap", "20261119T060000Z", nil, `{"id":"a","v":1}`)
	part := filepath.Join(f.raw, filepath.FromSlash(id), "data", "part-0.ndjson")
	body, _ := os.ReadFile(part)
	os.Remove(part)
	rep := f.report(Options{})
	want(t, skipped(rep), []string{"snap"})
	if n := f.count(`SELECT count(*) FROM ledger`); n != 0 {
		t.Fatalf("ledger rows after a failed rebuild = %d, want 0", n)
	}

	os.WriteFile(part, body, 0o644)
	want(t, statuses(f.run(Options{})), []string{"accepted", "accepted", "accepted"})
	want(t, f.rows("snap"), []string{
		"a 11-19 06:00 11-20 06:00 changed 1",
		"a 11-20 06:00 11-21 06:00 changed 2",
		"a 11-21 06:00 - - 3",
	})
}

func TestFailedReconcileResumesWithFullListing(t *testing.T) {
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261101T060000Z", nil, `{"id":"a","v":1}`)
	f.run(Options{})
	// Two old batches arrive late; the first cannot be read.
	id := f.batch("snap", "20261102T060000Z", nil, `{"id":"a","v":2}`)
	f.batch("snap", "20261103T060000Z", nil, `{"id":"a","v":3}`)
	part := filepath.Join(f.raw, filepath.FromSlash(id), "data", "part-0.ndjson")
	body, _ := os.ReadFile(part)
	os.Remove(part)
	want(t, skipped(f.report(Options{Reconcile: true})), []string{"snap"})

	if n := f.count(`SELECT count(*) FROM feed_state WHERE NOT history_complete`); n != 1 {
		t.Fatal("history is still marked complete after a failed reconcile")
	}

	// Without -reconcile, the next pass still lists the whole history.
	os.WriteFile(part, body, 0o644)
	want(t, statuses(f.run(Options{})), []string{"accepted", "accepted"})
	want(t, f.rows("snap"), []string{
		"a 11-01 06:00 11-02 06:00 changed 1",
		"a 11-02 06:00 11-03 06:00 changed 2",
		"a 11-03 06:00 - - 3",
	})
}

func TestMalformedMetaIsRejected(t *testing.T) {
	f := newFixture(t, snapFeed)
	id := f.batch("snap", "20261120T060000Z", nil, `{"id":"a","v":1}`)
	os.WriteFile(filepath.Join(f.raw, filepath.FromSlash(id), "_meta.json"), []byte(`{"objects":`), 0o644)
	rs := f.run(Options{})
	want(t, statuses(rs), []string{"rejected"})
	if !strings.HasPrefix(rs[0].Reason, "malformed input: ") {
		t.Fatalf("reason = %q", rs[0].Reason)
	}
}

func TestExpressionErrorSkipsFeed(t *testing.T) {
	// A feed expression that throws is a pack fault, not bad input: the
	// batch must not be rejected, so it loads once the pack is fixed.
	f := newFixture(t, `INSERT INTO feed_manifest
		(feed_id, pack_id, kind, format, identity, valid_from, required, provenance)
		VALUES ('ev', 'test', 'event', 'ndjson', $$CAST(json->>'$.id' AS INTEGER)::VARCHAR$$,
		        $$meta->>'$.read_time'$$, [], 'config')`)
	f.batch("ev", "20261120T060000Z", nil, `{"id":"x"}`)
	rep := f.report(Options{})
	want(t, skipped(rep), []string{"ev"})
	if n := f.count(`SELECT count(*) FROM ledger`); n != 0 {
		t.Fatalf("ledger rows = %d, want 0", n)
	}
}

func TestLateEventWithLaterRunDoesNotMove(t *testing.T) {
	f := newFixture(t, eventFeed)
	early := f.batch("ev", "20261120T060000Z", nil, `{"id":"e1","v":1}`)
	f.batch("ev", "20261122T060000Z", nil, `{"id":"e2","v":1}`)
	f.run(Options{})
	f.batch("ev", "20261121T060000Z", nil, `{"id":"e1","v":1}`)
	f.run(Options{})
	want(t, f.rows("ev"), []string{"e1 11-20 06:00 - - 1", "e2 11-22 06:00 - - 1"})
	if n := f.count(`SELECT count(*) FROM record WHERE record_id = 'e1' AND batch_id = ?`, early); n != 1 {
		t.Fatal("e1 moved away from its earliest batch")
	}
}

func TestLateEventWithDifferentContentAppends(t *testing.T) {
	f := newFixture(t, eventFeed)
	f.batch("ev", "20261121T060000Z", nil, `{"id":"e1","v":2}`)
	f.run(Options{})
	f.batch("ev", "20261120T060000Z", nil, `{"id":"e1","v":1}`)
	f.run(Options{})
	want(t, f.rows("ev"), []string{"e1 11-20 06:00 - - 1", "e1 11-21 06:00 - - 2"})
}

func TestValidFromAfterNextBatchKeepsRowsOrdered(t *testing.T) {
	// The record claims a change time later than the next batch's run. The
	// new row cannot start before the old row did, so it starts at the old
	// row's start, and the old row closes there with zero length.
	f := newFixture(t, snapFeed)
	f.batch("snap", "20261120T060000Z", nil, `{"id":"a","t":"2026-11-22T00:00:00Z","v":1}`)
	f.batch("snap", "20261121T060000Z", nil, `{"id":"a","t":"2026-11-22T00:00:00Z","v":2}`)
	f.run(Options{})
	want(t, f.rows("snap"), []string{
		"a 11-22 00:00 11-22 00:00 changed 1",
		"a 11-22 00:00 - - 2",
	})
}

func TestObjectsThatIsNotAListRejectsBatch(t *testing.T) {
	// Without this check a scoped batch would read as empty and close every
	// row in the scopes it covers.
	f := newFixture(t, scopedFeed)
	ok := map[string]any{"imgA": map[string]any{"status": "ok"}}
	f.batch("aa", "20261120T060000Z", map[string]any{"statuses": ok}, `{"id":"a1","img":"imgA"}`)
	id := f.batch("aa", "20261121T060000Z", map[string]any{"statuses": ok})
	os.WriteFile(filepath.Join(f.raw, filepath.FromSlash(id), "_meta.json"),
		[]byte(`{"read_time":"2026-11-21T06:00:00Z","statuses":{"imgA":{"status":"ok"}},"objects":"oops"}`), 0o644)
	rs := f.run(Options{})
	want(t, statuses(rs), []string{"accepted", "rejected"})
	if rs[1].Reason != "_meta.json objects is missing or not a list" {
		t.Fatalf("reason = %q", rs[1].Reason)
	}
	want(t, f.rows("aa"), []string{"a1 11-20 06:00 - - -"})
}
