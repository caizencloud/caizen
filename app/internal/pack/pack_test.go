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
	if n != 11 {
		t.Fatalf("feeds = %d, want 11", n)
	}
	// A second load replaces the rows instead of adding to them.
	if _, err := Load(ctx, d.DB, root); err != nil {
		t.Fatal(err)
	}
	if err := d.QueryRow(`SELECT count(*) FROM feed_manifest`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 11 {
		t.Fatalf("feeds after reload = %d, want 11", n)
	}
}

// writePacks creates one directory per pack with a pack.toml and feeds.sql.
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
