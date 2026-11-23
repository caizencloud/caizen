// Package pack loads packs from a local directory or from a gs:// prefix
// that holds one published pack digest.
//
// A pack is a directory with a pack.toml and optional SQL files:
// vocabulary.sql, feeds.sql, views.sql, nodes.sql, and rules/*.sql. Packs
// load in topological order over requires, with ties broken by ID, and
// each pack's files load in that order. Rows a pack inserts must carry its
// pack_id, and views and macros it creates must be named <pack>_*. The
// loader stores nodes.sql and the rules for the model rebuild to run. All
// reads go through DuckDB, so local and gs:// roots use the same code.
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

// Load reads every <root>/*/pack.toml, orders the packs, and replaces every
// pack row, view, and macro with those of the packs found.
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
	if err := loadAll(ctx, d, ordered); err != nil {
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

// The SQL files a pack may hold, in load order. Rows each file inserts must
// carry the pack's pack_id.
var sqlFiles = []string{"vocabulary.sql", "feeds.sql", "views.sql"}

// loadAll replaces every pack row, view, and macro in one transaction. For
// each pack in order it runs vocabulary.sql, feeds.sql, and views.sql, and
// stores nodes.sql and rules/*.sql for the model rebuild to run.
func loadAll(ctx context.Context, d *sql.DB, packs []Pack) error {
	tx, err := d.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := dropObjects(ctx, tx); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, query("clear")); err != nil {
		return err
	}
	for _, p := range packs {
		if err := loadPack(ctx, tx, p); err != nil {
			return err
		}
	}

	var problem, detail string
	err = tx.QueryRowContext(ctx, query("invalid")).Scan(&problem, &detail)
	if err == nil {
		return fmt.Errorf("%s: %s", problem, detail)
	}
	if err != sql.ErrNoRows {
		return err
	}
	return tx.Commit()
}

func loadPack(ctx context.Context, tx *sql.Tx, p Pack) error {
	for _, name := range sqlFiles {
		file := p.Dir + "/" + name
		content, ok, err := readOne(ctx, tx, file)
		if err != nil {
			return err
		}
		if !ok {
			continue
		}
		before, err := objects(ctx, tx)
		if err != nil {
			return err
		}
		if err := owned(ctx, tx, p.ID, file, func() error {
			_, err := tx.ExecContext(ctx, content)
			return err
		}); err != nil {
			return err
		}
		after, err := objects(ctx, tx)
		if err != nil {
			return err
		}
		for obj := range after {
			if !before[obj] && !strings.HasPrefix(obj[strings.LastIndex(obj, " ")+1:], p.ID+"_") {
				return fmt.Errorf("%s: %s is not named with the prefix %s_", file, obj, p.ID)
			}
		}
	}

	nodes, ok, err := readOne(ctx, tx, p.Dir+"/nodes.sql")
	if err != nil {
		return err
	}
	if ok {
		if _, err := tx.ExecContext(ctx, query("query_insert"), p.ID, "nodes", "nodes", nodes); err != nil {
			return err
		}
	}

	rows, err := tx.QueryContext(ctx, query("read_files"), p.Dir+"/rules/*.sql")
	if err != nil {
		return fmt.Errorf("read %s/rules: %w", p.Dir, err)
	}
	type rule struct{ name, sql string }
	var rules []rule
	for rows.Next() {
		var file, content string
		if err := rows.Scan(&file, &content); err != nil {
			rows.Close()
			return err
		}
		rules = append(rules, rule{strings.TrimSuffix(file[strings.LastIndex(file, "/")+1:], ".sql"), content})
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}
	for _, r := range rules {
		if _, err := tx.ExecContext(ctx, query("query_insert"), p.ID, "rule", r.name, r.sql); err != nil {
			return err
		}
	}
	return nil
}

// readOne returns a file's content, or ok=false when it does not exist.
func readOne(ctx context.Context, tx *sql.Tx, file string) (string, bool, error) {
	var n int
	if err := tx.QueryRowContext(ctx, query("exists"), file).Scan(&n); err != nil {
		return "", false, err
	}
	if n == 0 {
		return "", false, nil
	}
	var content string
	if err := tx.QueryRowContext(ctx, query("read_one"), file).Scan(&content); err != nil {
		return "", false, fmt.Errorf("read %s: %w", file, err)
	}
	return content, true, nil
}

// owned runs fn and fails if it inserted rows under a pack_id other than
// packID.
func owned(ctx context.Context, tx *sql.Tx, packID, file string, fn func() error) error {
	var before, ownBefore, after, ownAfter int
	if err := tx.QueryRowContext(ctx, query("owned"), packID).Scan(&before, &ownBefore); err != nil {
		return err
	}
	if err := fn(); err != nil {
		return fmt.Errorf("%s: %w", file, err)
	}
	if err := tx.QueryRowContext(ctx, query("owned"), packID).Scan(&after, &ownAfter); err != nil {
		return err
	}
	if after-before != ownAfter-ownBefore {
		return fmt.Errorf("%s: inserted rows under a pack_id other than %q", file, packID)
	}
	return nil
}

// objects returns the views and macros in the main schema, as "KIND name".
func objects(ctx context.Context, tx *sql.Tx) (map[string]bool, error) {
	rows, err := tx.QueryContext(ctx, query("objects"))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]bool{}
	for rows.Next() {
		var kind, name string
		if err := rows.Scan(&kind, &name); err != nil {
			return nil, err
		}
		out[kind+" "+name] = true
	}
	return out, rows.Err()
}

// dropObjects drops every view, then every macro, that a previous load
// created. Packs create all of them.
func dropObjects(ctx context.Context, tx *sql.Tx) error {
	objs, err := objects(ctx, tx)
	if err != nil {
		return err
	}
	var views, macros []string
	for obj := range objs {
		if strings.HasPrefix(obj, "VIEW ") {
			views = append(views, obj)
		} else {
			macros = append(macros, obj)
		}
	}
	sort.Strings(views)
	sort.Strings(macros)
	for _, obj := range append(views, macros...) {
		i := strings.LastIndex(obj, " ")
		if _, err := tx.ExecContext(ctx, "DROP "+obj[:i]+" "+quoteIdent(obj[i+1:])); err != nil {
			return err
		}
	}
	return nil
}

func quoteIdent(s string) string {
	return `"` + strings.ReplaceAll(s, `"`, `""`) + `"`
}
