package score

import (
	"context"
	"fmt"
	"reflect"
	"strings"
	"testing"

	"github.com/caizencloud/caizen/app/internal/db"
)

// Each test fills edge_type, abstract_edge, and goal directly and states the
// chains it expects from the traversal rules (ADR-0006, ADR-0007).

const types = `INSERT INTO edge_type VALUES
    ('core', 'network_access', NULL, 'reach', 1.0),
    ('core', 'code_execution', NULL, 'exec', 1.0),
    ('core', 'credential_access', 'exec', 'hold', 1.0),
    ('core', 'priv_esc', 'hold', 'control', 1.0)`

func setup(t *testing.T, goals string, edges ...string) *db.DB {
	t.Helper()
	d, err := db.Open(context.Background(), db.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { d.Close() })
	if _, err := d.Exec(types); err != nil {
		t.Fatal(err)
	}
	for _, e := range edges {
		// "src dst etype confidence"
		f := strings.Fields(e)
		if _, err := d.Exec(`INSERT INTO abstract_edge VALUES ('p', 'r-' || ? || '-' || ?, ?, ?, 'compute', 'compute', ?,
			'p', NULL, NULL, NULL, 'config', '{}', 'tc', 1.0, CAST(? AS DOUBLE))`, f[0], f[1], f[0], f[1], f[2], f[3]); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := d.Exec(`INSERT INTO goal SELECT * FROM (VALUES ` + goals + `) t(node_id, value)`); err != nil {
		t.Fatal(err)
	}
	return d
}

func chains(t *testing.T, d *db.DB, opts Options) []string {
	t.Helper()
	if _, err := Run(context.Background(), d.DB, opts); err != nil {
		t.Fatal(err)
	}
	rows, err := d.Query(`SELECT array_to_string(path, '>') || ' ' || round(confidence, 3) || ' ' || CAST(round(score) AS BIGINT)
		FROM chain ORDER BY score DESC, path`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var s string
		if err := rows.Scan(&s); err != nil {
			t.Fatal(err)
		}
		out = append(out, s)
	}
	return out
}

func want(t *testing.T, got, want []string) {
	t.Helper()
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("chains:\n got  %q\n want %q", got, want)
	}
}

func TestReachAloneDoesNotGrantCredentialAccess(t *testing.T) {
	// network_access grants reach; credential_access requires exec.
	d := setup(t, "('org', 1000)",
		"i svc network_access 1.0",
		"svc sa credential_access 1.0",
		"sa org priv_esc 1.0")
	want(t, chains(t, d, Options{}), nil)
}

func TestExecutionChainsToGoal(t *testing.T) {
	d := setup(t, "('org', 1000), ('sa', 10)",
		"i svc code_execution 0.5",
		"svc sa credential_access 0.8",
		"sa org priv_esc 1.0")
	// Every walk that ends at a goal is a chain; the walk through sa to org
	// is a second chain.
	want(t, chains(t, d, Options{}), []string{"i>svc>sa>org 0.4 400", "i>svc>sa 0.4 4"})
}

func TestCyclePruneAndDepth(t *testing.T) {
	d := setup(t, "('d', 100)",
		"a b code_execution 1.0",
		"b c code_execution 1.0",
		"c a code_execution 1.0", // a cycle back to the start
		"c d code_execution 1.0",
		"x d code_execution 0.02") // at the prune threshold, so dropped
	want(t, chains(t, d, Options{}), []string{"a>b>c>d 1.0 100", "b>c>d 1.0 100", "c>d 1.0 100"})
	// With at most 2 hops, a>b>c>d no longer fits.
	want(t, chains(t, d, Options{MaxHops: 2}), []string{"b>c>d 1.0 100", "c>d 1.0 100"})
}

func TestChokeSumsScoresThroughEachEdge(t *testing.T) {
	d := setup(t, "('g1', 100), ('g2', 50)",
		"i svc code_execution 1.0",
		"svc sa credential_access 1.0",
		"sa g1 priv_esc 1.0",
		"sa g2 priv_esc 1.0")
	if _, err := Run(context.Background(), d.DB, Options{}); err != nil {
		t.Fatal(err)
	}
	_, chokes, err := Top(context.Background(), d.DB, 10)
	if err != nil {
		t.Fatal(err)
	}
	var got []string
	for _, c := range chokes {
		got = append(got, fmt.Sprintf("%s>%s %g %d", c.Src, c.Dst, c.Value, c.Chains))
	}
	want(t, got, []string{"i>svc 150 2", "svc>sa 150 2", "sa>g1 100 1", "sa>g2 50 1"})
}
