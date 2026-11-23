// Package model rebuilds the attack-path model from the packs' nodes.sql
// and rules.
//
// A rebuild runs every nodes.sql into node and every rule into rule_edge,
// each in its own statement, so a failing query drops only its own rows.
// It then checks each rule edge for coherence (ADR-0016), sets the
// confidence of each edge that passes, and computes the goals, in one
// transaction. Fixed SQL lives in sql/*.sql. The statements that wrap a
// pack's query are built here.
package model

import (
	"context"
	"database/sql"
	"embed"
	"fmt"

	"github.com/caizencloud/caizen/app/internal/db"
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

// Report is the outcome of one Rebuild.
type Report struct {
	Nodes   int64
	Edges   int64 // edges that passed the coherence checks
	Rejects int64 // edges that failed them, in edge_reject
	Goals   int64
	// Failed holds the queries that failed. Each one contributed no rows.
	Failed []Failure
}

// Failure names a pack query that failed.
type Failure struct {
	Pack string
	Name string // "nodes" or the rule name
	Err  error
}

// Rebuild replaces node, rule_edge, edge_reject, abstract_edge, and goal.
// It returns an error when it cannot finish, including when two queries
// emit the same node ID.
func Rebuild(ctx context.Context, d *sql.DB) (Report, error) {
	var rep Report
	conn, err := d.Conn(ctx)
	if err != nil {
		return rep, err
	}
	defer conn.Close()

	if _, err := conn.ExecContext(ctx, query("clear")); err != nil {
		return rep, err
	}
	type packQuery struct{ pack, kind, name, sql string }
	var qs []packQuery
	rows, err := conn.QueryContext(ctx, query("queries"))
	if err != nil {
		return rep, err
	}
	for rows.Next() {
		var q packQuery
		if err := rows.Scan(&q.pack, &q.kind, &q.name, &q.sql); err != nil {
			rows.Close()
			return rep, err
		}
		qs = append(qs, q)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return rep, err
	}

	for _, q := range qs {
		var stmt string
		switch q.kind {
		case "nodes":
			stmt = fmt.Sprintf(`INSERT INTO node
				SELECT q.id, q.label, t.abstract_types, %s
				FROM (%s) q LEFT JOIN node_type t USING (label)`, db.Quote(q.pack), q.sql)
		case "rule":
			stmt = fmt.Sprintf(`INSERT INTO rule_edge BY NAME
				SELECT %s AS pack_id, %s AS rule, * FROM (%s)`, db.Quote(q.pack), db.Quote(q.name), q.sql)
		}
		if _, err := conn.ExecContext(ctx, stmt); err != nil {
			rep.Failed = append(rep.Failed, Failure{Pack: q.pack, Name: q.name, Err: err})
		}
	}

	var id, packs string
	err = conn.QueryRowContext(ctx, query("node_duplicate")).Scan(&id, &packs)
	if err == nil {
		return rep, fmt.Errorf("node %s is emitted more than once, by %s", id, packs)
	}
	if err != sql.ErrNoRows {
		return rep, err
	}

	tx, err := conn.BeginTx(ctx, nil)
	if err != nil {
		return rep, err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, query("edges")); err != nil {
		return rep, err
	}
	err = tx.QueryRowContext(ctx, query("counts")).Scan(&rep.Nodes, &rep.Edges, &rep.Rejects, &rep.Goals)
	if err != nil {
		return rep, err
	}
	return rep, tx.Commit()
}
