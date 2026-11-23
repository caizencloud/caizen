package db

import (
	"context"
	"path/filepath"
	"strconv"
	"testing"
)

func open(t *testing.T, path string) *DB {
	t.Helper()
	db, err := Open(context.Background(), Options{Path: path})
	if err != nil {
		t.Fatal(err)
	}
	return db
}

func TestOpenNewFileIsFresh(t *testing.T) {
	db := open(t, filepath.Join(t.TempDir(), "c.duckdb"))
	defer db.Close()
	if !db.Fresh {
		t.Fatal("new file: Fresh = false, want true")
	}
	var v string
	if err := db.QueryRow(`SELECT value FROM caizen_meta WHERE key = 'schema_version'`).Scan(&v); err != nil {
		t.Fatal(err)
	}
	if want := strconv.Itoa(SchemaVersion); v != want {
		t.Fatalf("schema_version = %q, want %q", v, want)
	}
}

func TestReopenKeepsData(t *testing.T) {
	path := filepath.Join(t.TempDir(), "c.duckdb")
	db := open(t, path)
	if _, err := db.Exec(`CREATE TABLE keep AS SELECT 1 AS x`); err != nil {
		t.Fatal(err)
	}
	db.Close()

	db = open(t, path)
	defer db.Close()
	if db.Fresh {
		t.Fatal("reopen: Fresh = true, want false")
	}
	var x int
	if err := db.QueryRow(`SELECT x FROM keep`).Scan(&x); err != nil {
		t.Fatal(err)
	}
}

func TestVersionMismatchRebuilds(t *testing.T) {
	path := filepath.Join(t.TempDir(), "c.duckdb")
	db := open(t, path)
	for _, stmt := range []string{
		`CREATE TABLE stale AS SELECT 1 AS x`,
		`UPDATE caizen_meta SET value = '0' WHERE key = 'schema_version'`,
	} {
		if _, err := db.Exec(stmt); err != nil {
			t.Fatal(err)
		}
	}
	db.Close()

	db = open(t, path)
	defer db.Close()
	if !db.Fresh {
		t.Fatal("old version: Fresh = false, want true")
	}
	var n int
	if err := db.QueryRow(`SELECT count(*) FROM information_schema.tables WHERE table_name = 'stale'`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 0 {
		t.Fatal("table from the old file survived the rebuild")
	}
}

func TestInMemory(t *testing.T) {
	db := open(t, "")
	defer db.Close()
	if !db.Fresh {
		t.Fatal("in-memory: Fresh = false, want true")
	}
}
