// Package db opens the Caizen DuckDB file and applies the engine schema.
//
// The DuckDB file is a cache. Everything in it is rebuilt by replaying raw/
// from the data bucket. When the file's stored schema version differs from
// SchemaVersion, Open deletes the file and creates a new one. The caller then
// replays raw/.
package db

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"embed"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"sort"
	"strconv"
	"strings"

	"github.com/duckdb/duckdb-go/v2"
)

// SchemaVersion is the engine schema version. Increase it whenever a change
// to schema/*.sql, or to any package's embedded DDL, needs a rebuild.
const SchemaVersion = 3

//go:embed schema/*.sql
var schemaFS embed.FS

// Options configures Open.
type Options struct {
	// Path is the DuckDB file. An empty path opens an in-memory database.
	Path string
	// Remote loads the gcs extension and an Application Default Credentials
	// secret, so that DuckDB can read and write gs:// URIs.
	Remote bool
}

// DB is an open Caizen database.
type DB struct {
	*sql.DB
	// Fresh is true when Open created the schema, either because the file
	// was new or because its schema version was out of date. The caller
	// must then replay raw/.
	Fresh bool
}

// Open opens or creates the database at opts.Path.
func Open(ctx context.Context, opts Options) (*DB, error) {
	existed := false
	if opts.Path != "" {
		if _, err := os.Stat(opts.Path); err == nil {
			existed = true
		} else if !errors.Is(err, fs.ErrNotExist) {
			return nil, err
		}
	}

	conn, err := connect(opts.Path)
	if err != nil {
		return nil, err
	}

	if existed {
		current, err := storedVersion(ctx, conn)
		if err != nil {
			conn.Close()
			return nil, err
		}
		if !current {
			conn.Close()
			if err := remove(opts.Path); err != nil {
				return nil, err
			}
			if conn, err = connect(opts.Path); err != nil {
				return nil, err
			}
			existed = false
		}
	}

	db := &DB{DB: conn, Fresh: !existed}
	if db.Fresh {
		if err := applySchema(ctx, conn); err != nil {
			conn.Close()
			return nil, err
		}
	}
	if opts.Remote {
		if err := loadGCS(ctx, conn); err != nil {
			conn.Close()
			return nil, err
		}
	}
	return db, nil
}

// connect opens path. Every connection uses UTC, so that conversions between
// TIMESTAMP and TIMESTAMPTZ do not depend on the host time zone.
func connect(path string) (*sql.DB, error) {
	c, err := duckdb.NewConnector(path, func(execer driver.ExecerContext) error {
		_, err := execer.ExecContext(context.Background(), `SET TimeZone = 'UTC'`, nil)
		return err
	})
	if err != nil {
		return nil, fmt.Errorf("open %q: %w", path, err)
	}
	return sql.OpenDB(c), nil
}

// storedVersion reports whether the file holds the current schema version.
func storedVersion(ctx context.Context, conn *sql.DB) (bool, error) {
	var n int
	err := conn.QueryRowContext(ctx,
		`SELECT count(*) FROM information_schema.tables WHERE table_name = 'caizen_meta'`).Scan(&n)
	if err != nil || n == 0 {
		return false, err
	}
	var v string
	err = conn.QueryRowContext(ctx,
		`SELECT value FROM caizen_meta WHERE key = 'schema_version'`).Scan(&v)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return v == strconv.Itoa(SchemaVersion), nil
}

func remove(path string) error {
	for _, p := range []string{path, path + ".wal"} {
		if err := os.Remove(p); err != nil && !errors.Is(err, fs.ErrNotExist) {
			return err
		}
	}
	return nil
}

// applySchema runs schema/*.sql in name order and records SchemaVersion.
func applySchema(ctx context.Context, conn *sql.DB) error {
	names, err := fs.Glob(schemaFS, "schema/*.sql")
	if err != nil {
		return err
	}
	sort.Strings(names)
	tx, err := conn.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, name := range names {
		ddl, err := schemaFS.ReadFile(name)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, string(ddl)); err != nil {
			return fmt.Errorf("%s: %w", name, err)
		}
	}
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO caizen_meta (key, value) VALUES ('schema_version', ?)`,
		strconv.Itoa(SchemaVersion)); err != nil {
		return err
	}
	return tx.Commit()
}

// loadGCS loads the gcs community extension and a secret that uses
// Application Default Credentials. The container image pre-installs the
// extension, so INSTALL makes no network call there.
func loadGCS(ctx context.Context, conn *sql.DB) error {
	for _, stmt := range []string{
		`INSTALL gcs FROM community`,
		`LOAD gcs`,
		`CREATE OR REPLACE SECRET caizen_gcs (TYPE gcp, PROVIDER credential_chain)`,
	} {
		if _, err := conn.ExecContext(ctx, stmt); err != nil {
			return fmt.Errorf("%s: %w", stmt, err)
		}
	}
	return nil
}

// Quote returns s as a SQL string literal, for values that go into SQL built
// in Go: a reader's file list, a record_path, and required-expression labels.
func Quote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}
