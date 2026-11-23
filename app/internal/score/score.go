// Package score walks the model's abstract edges and ranks what it finds.
//
// It fills chain with every capability-gated walk that ends at a goal, and
// choke with the confidence-weighted value that flows through each edge on
// those chains (ADR-0006). Fixed SQL lives in sql/*.sql.
package score

import (
	"context"
	"database/sql"
	"embed"
)

//go:embed sql/*.sql
var sqlFS embed.FS

func query(name string) string {
	b, err := sqlFS.ReadFile("sql/" + name + ".sql")
	if err != nil {
		panic(err)
	}
	return string(b)
}

// Options configures Run.
type Options struct {
	// MaxHops bounds the length of a walk. Zero means 8.
	MaxHops int
	// Prune drops a walk whose confidence product falls to it or below.
	// Zero means 0.02.
	Prune float64
}

// Report is the outcome of one Run.
type Report struct {
	Chains int64
	Chokes int64
}

// Run replaces chain and choke in one transaction.
func Run(ctx context.Context, d *sql.DB, opts Options) (Report, error) {
	if opts.MaxHops == 0 {
		opts.MaxHops = 8
	}
	if opts.Prune == 0 {
		opts.Prune = 0.02
	}
	var rep Report
	tx, err := d.BeginTx(ctx, nil)
	if err != nil {
		return rep, err
	}
	defer tx.Rollback()
	for _, s := range []struct {
		q    string
		args []any
	}{
		{query("chain_clear"), nil},
		{query("chain_insert"), []any{opts.MaxHops, opts.Prune}},
		{query("choke"), nil},
	} {
		if _, err := tx.ExecContext(ctx, s.q, s.args...); err != nil {
			return rep, err
		}
	}
	err = tx.QueryRowContext(ctx, query("counts")).Scan(&rep.Chains, &rep.Chokes)
	if err != nil {
		return rep, err
	}
	return rep, tx.Commit()
}

// Chain is one row of chain.
type Chain struct {
	Path       []string `json:"path"`
	Etypes     []string `json:"etypes"`
	Rules      []string `json:"rules"`
	Confidence float64  `json:"confidence"`
	Value      int64    `json:"value"`
	Score      float64  `json:"score"`
}

// Choke is one row of choke.
type Choke struct {
	Src    string  `json:"src"`
	Dst    string  `json:"dst"`
	Etype  string  `json:"etype"`
	Chains int64   `json:"chains"`
	Value  float64 `json:"value"`
}

// Top returns the n highest-scoring chains and the n edges that carry the
// most value.
func Top(ctx context.Context, d *sql.DB, n int) ([]Chain, []Choke, error) {
	rows, err := d.QueryContext(ctx, query("top_chains"), n)
	if err != nil {
		return nil, nil, err
	}
	var chains []Chain
	for rows.Next() {
		var c Chain
		var path, etypes, rules []any
		if err := rows.Scan(&path, &etypes, &rules, &c.Confidence, &c.Value, &c.Score); err != nil {
			rows.Close()
			return nil, nil, err
		}
		c.Path, c.Etypes, c.Rules = strs(path), strs(etypes), strs(rules)
		chains = append(chains, c)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, nil, err
	}

	rows, err = d.QueryContext(ctx, query("top_chokes"), n)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()
	var chokes []Choke
	for rows.Next() {
		var c Choke
		if err := rows.Scan(&c.Src, &c.Dst, &c.Etype, &c.Chains, &c.Value); err != nil {
			return nil, nil, err
		}
		chokes = append(chokes, c)
	}
	return chains, chokes, rows.Err()
}

func strs(vs []any) []string {
	out := make([]string, len(vs))
	for i, v := range vs {
		out[i], _ = v.(string)
	}
	return out
}
