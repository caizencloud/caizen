package e2e

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/caizencloud/caizen/app/internal/db"
	"github.com/caizencloud/caizen/app/internal/ingest"
	"github.com/caizencloud/caizen/app/internal/model"
	"github.com/caizencloud/caizen/app/internal/pack"
	"github.com/caizencloud/caizen/app/internal/score"
)

// TestPackFixtures gates rules (ADR-0020 §6). Every pack with rules must
// have tests/fixtures, a raw/ tree in the real batch layout, and
// tests/assert.sql, a query that returns zero rows when the pack's rules
// behave as their intent lines say. The fixture loads through the real
// ingest with every repo pack, and the model is rebuilt and scored before
// the assertions run.
func TestPackFixtures(t *testing.T) {
	root, err := filepath.Abs("../../packs")
	if err != nil {
		t.Fatal(err)
	}
	withRules, err := filepath.Glob(filepath.Join(root, "*", "rules", "*.sql"))
	if err != nil {
		t.Fatal(err)
	}
	packs := map[string]bool{}
	for _, f := range withRules {
		packs[filepath.Base(filepath.Dir(filepath.Dir(f)))] = true
	}
	if len(packs) == 0 {
		t.Fatal("no pack has rules")
	}
	for id := range packs {
		t.Run(id, func(t *testing.T) { runFixture(t, root, id) })
	}
}

func runFixture(t *testing.T, root, id string) {
	ctx := context.Background()
	fixtures := filepath.Join(root, id, "tests", "fixtures")
	assert := filepath.Join(root, id, "tests", "assert.sql")
	for _, p := range []string{fixtures, assert} {
		if _, err := os.Stat(p); err != nil {
			t.Fatalf("pack %s has rules, so it needs %s: %v", id, p, err)
		}
	}

	d, err := db.Open(ctx, db.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer d.Close()
	if _, err := pack.Load(ctx, d.DB, root); err != nil {
		t.Fatal(err)
	}
	// The first pass lists each feed's whole history, so the clock only
	// has to be later than the fixture batches.
	rep, err := ingest.Run(ctx, d.DB, ingest.Options{Raw: fixtures, Now: time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC)})
	if err != nil {
		t.Fatal(err)
	}
	if len(rep.Skipped) > 0 {
		t.Fatalf("feeds skipped: %v", rep.Skipped)
	}
	for _, b := range rep.Batches {
		if b.Status != "accepted" && b.Status != "superseded" {
			t.Fatalf("fixture batch %s is %s: %s", b.Batch, b.Status, b.Reason)
		}
	}
	m, err := model.Rebuild(ctx, d.DB)
	if err != nil {
		t.Fatal(err)
	}
	if len(m.Failed) > 0 {
		t.Fatalf("pack queries failed: %v", m.Failed)
	}
	if _, err := score.Run(ctx, d.DB, score.Options{}); err != nil {
		t.Fatal(err)
	}
	check(t, d, assert)
}
