package pack

import (
	"context"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/caizencloud/caizen/app/internal/db"
)

func TestOrder(t *testing.T) {
	got, err := order([]Pack{
		{ID: "oci", Requires: []string{"core"}},
		{ID: "core"},
		{ID: "gcp", Requires: []string{"core", "oci"}},
		{ID: "github", Requires: []string{"core"}},
	})
	if err != nil {
		t.Fatal(err)
	}
	var ids []string
	for _, p := range got {
		ids = append(ids, p.ID)
	}
	if want := []string{"core", "github", "oci", "gcp"}; !reflect.DeepEqual(ids, want) {
		t.Fatalf("order = %v, want %v", ids, want)
	}
}

func TestOrderRejectsCycleAndMissing(t *testing.T) {
	if _, err := order([]Pack{{ID: "a", Requires: []string{"b"}}, {ID: "b", Requires: []string{"a"}}}); err == nil {
		t.Fatal("cycle: no error")
	}
	if _, err := order([]Pack{{ID: "a", Requires: []string{"core"}}}); err == nil {
		t.Fatal("missing requirement: no error")
	}
}

func TestLoadRepoPacks(t *testing.T) {
	ctx := context.Background()
	d, err := db.Open(ctx, db.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer d.Close()
	root, err := filepath.Abs("../../../packs")
	if err != nil {
		t.Fatal(err)
	}
	packs, err := Load(ctx, d.DB, root)
	if err != nil {
		t.Fatal(err)
	}
	if packs[0].ID != "core" {
		t.Fatalf("first pack = %q, want core", packs[0].ID)
	}
	var n int
	if err := d.QueryRow(`SELECT count(*) FROM feed_manifest`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 12 {
		t.Fatalf("feeds = %d, want 12", n)
	}
	// A second load replaces the rows instead of adding to them.
	if _, err := Load(ctx, d.DB, root); err != nil {
		t.Fatal(err)
	}
	if err := d.QueryRow(`SELECT count(*) FROM feed_manifest`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 12 {
		t.Fatalf("feeds after reload = %d, want 12", n)
	}
}

// writePacks creates one directory per pack with a pack.toml, and a feeds.sql
// when the given SQL is not empty.
func writePacks(t *testing.T, feeds map[string]string) string {
	t.Helper()
	root := t.TempDir()
	for id, sql := range feeds {
		dir := filepath.Join(root, id)
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
		toml := "id = \"" + id + "\"\nversion = \"0.1.0\"\n"
		if err := os.WriteFile(filepath.Join(dir, "pack.toml"), []byte(toml), 0o644); err != nil {
			t.Fatal(err)
		}
		if sql == "" {
			continue
		}
		if err := os.WriteFile(filepath.Join(dir, "feeds.sql"), []byte(sql), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return root
}

func feedRow(feedID, packID string) string {
	return `INSERT INTO feed_manifest (feed_id, pack_id, kind, format, identity, valid_from, provenance)
		VALUES ('` + feedID + `', '` + packID + `', 'event', 'ndjson', 'x', 'x', 'config');`
}

func TestLoadRejectsRowsUnderAnotherPack(t *testing.T) {
	d, err := db.Open(context.Background(), db.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer d.Close()
	root := writePacks(t, map[string]string{"a": feedRow("f1", "b")})
	if _, err := Load(context.Background(), d.DB, root); err == nil || !strings.Contains(err.Error(), "pack_id other than") {
		t.Fatalf("err = %v, want a pack_id error", err)
	}
}

func TestLoadRejectsDuplicateFeed(t *testing.T) {
	d, err := db.Open(context.Background(), db.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer d.Close()
	root := writePacks(t, map[string]string{"a": feedRow("f1", "a"), "b": feedRow("f1", "b")})
	if _, err := Load(context.Background(), d.DB, root); err == nil || !strings.Contains(err.Error(), "declared more than once") {
		t.Fatalf("err = %v, want a duplicate-feed error", err)
	}
}

// writeFile adds one file under a pack directory created by writePacks.
func writeFile(t *testing.T, root, rel, body string) {
	t.Helper()
	p := filepath.Join(root, filepath.FromSlash(rel))
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func loadErr(t *testing.T, root string) error {
	t.Helper()
	d, err := db.Open(context.Background(), db.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { d.Close() })
	_, err = Load(context.Background(), d.DB, root)
	return err
}

func TestLoadRejectsUnprefixedView(t *testing.T) {
	root := writePacks(t, map[string]string{"a": ""})
	writeFile(t, root, "a/views.sql", `CREATE VIEW a_ok AS SELECT 1; CREATE VIEW stray AS SELECT 1;`)
	if err := loadErr(t, root); err == nil || !strings.Contains(err.Error(), "VIEW stray is not named with the prefix a_") {
		t.Fatalf("err = %v, want a prefix error", err)
	}
}

func TestLoadRejectsEdgeTypeOutsideCore(t *testing.T) {
	root := writePacks(t, map[string]string{"a": ""})
	writeFile(t, root, "a/vocabulary.sql", `INSERT INTO edge_type VALUES ('a', 'x', NULL, 'exec', 1.0);`)
	if err := loadErr(t, root); err == nil || !strings.Contains(err.Error(), "only the core pack may declare edge types") {
		t.Fatalf("err = %v, want a core-only error", err)
	}
}

func TestLoadStoresNodesAndRulesAndReplacesViews(t *testing.T) {
	ctx := context.Background()
	root := writePacks(t, map[string]string{"a": ""})
	writeFile(t, root, "a/views.sql", `CREATE VIEW a_v AS SELECT 1 AS x; CREATE MACRO a_m(y) AS y + 1; CREATE MACRO a_t() AS TABLE SELECT 1 AS z;`)
	writeFile(t, root, "a/nodes.sql", `SELECT 'caizen://x' AS id, 'caizen/X' AS label`)
	writeFile(t, root, "a/rules/01-one.sql", `SELECT 1`)
	writeFile(t, root, "a/rules/02-two.sql", `SELECT 2`)
	d, err := db.Open(ctx, db.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer d.Close()
	for i := 0; i < 2; i++ { // a second load drops and recreates the views
		if _, err := Load(ctx, d.DB, root); err != nil {
			t.Fatalf("load %d: %v", i, err)
		}
	}
	var got string
	if err := d.QueryRow(`SELECT string_agg(kind || ':' || name, ',' ORDER BY kind, name) FROM pack_query`).Scan(&got); err != nil {
		t.Fatal(err)
	}
	if want := "nodes:nodes,rule:01-one,rule:02-two"; got != want {
		t.Fatalf("pack_query = %q, want %q", got, want)
	}
	var n int
	if err := d.QueryRow(`SELECT a_m(x) FROM a_v`).Scan(&n); err != nil || n != 2 {
		t.Fatalf("a_m(a_v.x) = %d, %v; want 2", n, err)
	}
}
