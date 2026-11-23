// Package pack loads packs from a local directory or from a gs:// prefix
// that holds one published pack digest.
//
// A pack is a directory with a pack.toml and optional SQL files. Packs load
// in topological order over requires, with ties broken by ID. Today the
// loader runs feeds.sql only. All reads go through DuckDB, so local and gs://
// roots use the same code.
package pack

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"sort"
	"strings"

	"github.com/BurntSushi/toml"
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

// Pack is one parsed pack.toml.
type Pack struct {
	ID       string   `toml:"id"`
	Version  string   `toml:"version"`
	License  string   `toml:"license"`
	Requires []string `toml:"requires"`
	// Dir is the pack directory under the root.
	Dir string `toml:"-"`
}

// Load reads every <root>/*/pack.toml, orders the packs, and replaces the
// contents of feed_manifest with the rows from each pack's feeds.sql.
func Load(ctx context.Context, d *sql.DB, root string) ([]Pack, error) {
	root = strings.TrimSuffix(root, "/")
	packs, err := readPacks(ctx, d, root)
	if err != nil {
		return nil, err
	}
	ordered, err := order(packs)
	if err != nil {
		return nil, err
	}
	if err := loadFeeds(ctx, d, ordered); err != nil {
		return nil, err
	}
	return ordered, nil
}

func readPacks(ctx context.Context, d *sql.DB, root string) ([]Pack, error) {
	rows, err := d.QueryContext(ctx, query("read_files"), root+"/*/pack.toml")
	if err != nil {
		return nil, fmt.Errorf("read pack.toml files under %s: %w", root, err)
	}
	defer rows.Close()

	var packs []Pack
	seen := map[string]bool{}
	for rows.Next() {
		var file, content string
		if err := rows.Scan(&file, &content); err != nil {
			return nil, err
		}
		var p Pack
		if _, err := toml.Decode(content, &p); err != nil {
			return nil, fmt.Errorf("%s: %w", file, err)
		}
		// path.Dir would turn gs:// into gs:/, so split by hand.
		p.Dir = file[:strings.LastIndex(file, "/")]
		if p.ID != p.Dir[strings.LastIndex(p.Dir, "/")+1:] {
			return nil, fmt.Errorf("%s: id %q does not match its directory", file, p.ID)
		}
		if seen[p.ID] {
			return nil, fmt.Errorf("pack %q appears twice", p.ID)
		}
		seen[p.ID] = true
		packs = append(packs, p)
	}
	return packs, rows.Err()
}

// order sorts packs so that each pack follows the packs it requires.
func order(packs []Pack) ([]Pack, error) {
	byID := map[string]Pack{}
	for _, p := range packs {
		byID[p.ID] = p
	}
	for _, p := range packs {
		for _, r := range p.Requires {
			if _, ok := byID[r]; !ok {
				return nil, fmt.Errorf("pack %q requires %q, which is not present", p.ID, r)
			}
		}
	}

	var out []Pack
	done := map[string]bool{}
	for len(out) < len(packs) {
		var ready []string
		for _, p := range packs {
			if done[p.ID] {
				continue
			}
			ok := true
			for _, r := range p.Requires {
				ok = ok && done[r]
			}
			if ok {
				ready = append(ready, p.ID)
			}
		}
		if len(ready) == 0 {
			return nil, fmt.Errorf("packs have a requires cycle")
		}
		sort.Strings(ready)
		for _, id := range ready {
			done[id] = true
			out = append(out, byID[id])
		}
	}
	return out, nil
}

// loadFeeds runs each pack's feeds.sql in one transaction. Each pack may
// insert rows only under its own pack_id.
func loadFeeds(ctx context.Context, d *sql.DB, packs []Pack) error {
	tx, err := d.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, query("clear")); err != nil {
		return err
	}
	for _, p := range packs {
		file := p.Dir + "/feeds.sql"
		var n int
		if err := tx.QueryRowContext(ctx, query("exists"), file).Scan(&n); err != nil {
			return err
		}
		if n == 0 {
			continue
		}
		var content string
		if err := tx.QueryRowContext(ctx, query("read_one"), file).Scan(&content); err != nil {
			return fmt.Errorf("read %s: %w", file, err)
		}

		var before, after, own int
		if err := tx.QueryRowContext(ctx, query("count")).Scan(&before); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, content); err != nil {
			return fmt.Errorf("%s: %w", file, err)
		}
		if err := tx.QueryRowContext(ctx, query("counts"), p.ID).Scan(&after, &own); err != nil {
			return err
		}
		if after-before != own {
			return fmt.Errorf("%s: inserted rows under a pack_id other than %q", file, p.ID)
		}
	}

	var dup sql.NullString
	err = tx.QueryRowContext(ctx, query("duplicate")).Scan(&dup)
	if err == nil {
		return fmt.Errorf("feed %q is declared more than once", dup.String)
	}
	if err != sql.ErrNoRows {
		return err
	}
	return tx.Commit()
}
