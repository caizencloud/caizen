// Package e2e loads the frozen collector capture in testdata/raw with the
// repo's packs and runs the checks in testdata/expected.
//
// Each expected/*.sql file is a query that returns zero rows when its check
// passes. The expectations come from the capture and the lonimbus plan,
// never from running the loader.
package e2e

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/caizencloud/caizen/app/internal/db"
	"github.com/caizencloud/caizen/app/internal/ingest"
	"github.com/caizencloud/caizen/app/internal/pack"
)

func TestIngestFrozenCapture(t *testing.T) {
	ctx := context.Background()
	raw, err := filepath.Abs("testdata/raw")
	if err != nil {
		t.Fatal(err)
	}
	packs, err := filepath.Abs("../../packs")
	if err != nil {
		t.Fatal(err)
	}

	d, err := db.Open(ctx, db.Options{Path: filepath.Join(t.TempDir(), "e2e.duckdb")})
	if err != nil {
		t.Fatal(err)
	}
	defer d.Close()
	if _, err := pack.Load(ctx, d.DB, packs); err != nil {
		t.Fatal(err)
	}

	// The day after the newest capture (github-api, 2026-11-23), so the second
	// pass lists every captured ingest_dt partition again.
	opts := ingest.Options{Raw: raw, Now: time.Date(2026, 11, 24, 12, 0, 0, 0, time.UTC)}
	rep, err := ingest.Run(ctx, d.DB, opts)
	if err != nil {
		t.Fatal(err)
	}
	if len(rep.Batches) != 12 || len(rep.Skipped) != 0 {
		t.Fatalf("first pass decided %d batches and skipped %v, want 12 and none", len(rep.Batches), rep.Skipped)
	}

	files, err := filepath.Glob("testdata/expected/*.sql")
	if err != nil || len(files) == 0 {
		t.Fatalf("no expected checks found: %v", err)
	}
	for _, f := range files {
		t.Run(filepath.Base(f), func(t *testing.T) { check(t, d, f) })
	}

	t.Run("second pass writes nothing", func(t *testing.T) {
		before := counts(t, d)
		again, err := ingest.Run(ctx, d.DB, opts)
		if err != nil {
			t.Fatal(err)
		}
		if len(again.Batches) != 0 || len(again.Skipped) != 0 {
			t.Fatalf("second pass: %+v, want nothing", again)
		}
		if after := counts(t, d); after != before {
			t.Fatalf("row counts changed: before %v, after %v", before, after)
		}
	})
}

// check runs one expected query and fails with every row it returns.
func check(t *testing.T, d *db.DB, file string) {
	q, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	body := strings.TrimRight(strings.TrimSpace(string(q)), ";")
	rows, err := d.Query(`SELECT to_json(q)::VARCHAR FROM (` + body + `) q`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	for rows.Next() {
		var row string
		if err := rows.Scan(&row); err != nil {
			t.Fatal(err)
		}
		t.Error(row)
	}
	if err := rows.Err(); err != nil {
		t.Fatal(err)
	}
}

func counts(t *testing.T, d *db.DB) [3]int {
	var c [3]int
	err := d.QueryRow(`SELECT (SELECT count(*) FROM record), (SELECT count(*) FROM ledger),
		(SELECT count(*) FROM reject)`).Scan(&c[0], &c[1], &c[2])
	if err != nil {
		t.Fatal(err)
	}
	return c
}

// TestRepoCAIFeedRejectsNullAncestors checks the repo's gcp pack, not a test
// feed: a CAI record whose ancestors is a JSON null fails the required
// foreign ID, so the whole batch is rejected (ADR-0022 §5).
func TestRepoCAIFeedRejectsNullAncestors(t *testing.T) {
	ctx := context.Background()
	packs, err := filepath.Abs("../../packs")
	if err != nil {
		t.Fatal(err)
	}
	raw := t.TempDir()
	id := "gcp-cai-resource/ingest_dt=2026-11-19/run=20261119T060000Z"
	dir := filepath.Join(raw, filepath.FromSlash(id))
	if err := os.MkdirAll(filepath.Join(dir, "data"), 0o755); err != nil {
		t.Fatal(err)
	}
	lines := `{"name":"//x/a","asset_type":"t","ancestors":["projects/1"],"update_time":"2026-11-19T00:00:00Z"}
{"name":"//x/b","asset_type":"t","ancestors":null,"update_time":"2026-11-19T00:00:00Z"}
`
	meta := `{"read_time":"2026-11-19T06:00:00Z","objects":["gs://b/raw/` + id + `/data/part-0"]}`
	for name, body := range map[string]string{"data/part-0": lines, "_meta.json": meta, "_SUCCESS": ""} {
		if err := os.WriteFile(filepath.Join(dir, filepath.FromSlash(name)), []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	d, err := db.Open(ctx, db.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer d.Close()
	if _, err := pack.Load(ctx, d.DB, packs); err != nil {
		t.Fatal(err)
	}
	rep, err := ingest.Run(ctx, d.DB, ingest.Options{Raw: raw, Now: time.Date(2026, 11, 20, 0, 0, 0, 0, time.UTC)})
	if err != nil {
		t.Fatal(err)
	}
	if len(rep.Batches) != 1 || rep.Batches[0].Status != "rejected" ||
		rep.Batches[0].Reason != "1 records missing a required foreign ID" {
		t.Fatalf("batches = %+v, want one batch rejected for a missing foreign ID", rep.Batches)
	}
	var reason string
	if err := d.QueryRow(`SELECT reason FROM reject`).Scan(&reason); err != nil {
		t.Fatal(err)
	}
	if want := "missing required foreign ID: json->>'$.ancestors'"; reason != want {
		t.Fatalf("reject reason = %q, want %q", reason, want)
	}
}
