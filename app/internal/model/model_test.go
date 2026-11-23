package model

import (
	"context"
	"reflect"
	"strings"
	"testing"

	"github.com/caizencloud/caizen/app/internal/db"
)

// Each test fills the pack tables directly and states its expectations from
// the coherence and confidence rules, not from running Rebuild.

const vocab = `
INSERT INTO edge_type VALUES
    ('core', 'code_execution', NULL, 'exec', 1.0),
    ('core', 'credential_access', 'exec', 'hold', 0.995),
    ('core', 'contains', 'storage_access', NULL, 1.0);
INSERT INTO edge_endpoint VALUES
    ('core', 'code_execution', 'internet', 'compute'),
    ('core', 'credential_access', 'compute', 'credentials'),
    ('core', 'contains', 'storage', 'data');
INSERT INTO node_type VALUES
    ('core', 'caizen/Internet', ['internet']),
    ('core', 'caizen/UnscannedContents', ['data']),
    ('p', 'x/Service', ['compute']),
    ('p', 'x/Account', ['identity', 'credentials']),
    ('p', 'x/Bucket', ['storage']),
    ('p', 'x/Org', ['control_plane']);
INSERT INTO class_value VALUES ('core', 'control_plane:org', 100000);
INSERT INTO value_class VALUES ('p', 'x/Org', 'control_plane:org');
INSERT INTO storage_prior VALUES ('p', 'x/Bucket', 15000);
`

const nodes = `SELECT * FROM (VALUES
    ('caizen://internet', 'caizen/Internet'),
    ('x://svc', 'x/Service'),
    ('x://sa', 'x/Account'),
    ('x://bucket', 'x/Bucket'),
    ('x://bucket#contents', 'caizen/UnscannedContents'),
    ('x://org', 'x/Org'),
    ('x://untyped', 'x/Unknown')) t(id, label)`

// edge returns a rule SELECT for one edge with the given overrides.
func edge(src, dst, srcType, dstType, etype, provenance, basis string) string {
	b := "NULL"
	if basis != "" {
		b = "'" + basis + "'"
	}
	return `SELECT '` + src + `' AS src, '` + dst + `' AS dst, '` + srcType + `' AS src_type, '` + dstType +
		`' AS dst_type, '` + etype + `' AS etype, 'p' AS phase, '` + provenance + `' AS provenance, ` + b +
		` AS basis, '{}' AS witness, 'tc' AS truth_condition`
}

func setup(t *testing.T, rules map[string]string) *db.DB {
	t.Helper()
	d, err := db.Open(context.Background(), db.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { d.Close() })
	if _, err := d.Exec(vocab); err != nil {
		t.Fatal(err)
	}
	if _, err := d.Exec(`INSERT INTO pack_query VALUES ('p', 'nodes', 'nodes', ?)`, nodes); err != nil {
		t.Fatal(err)
	}
	for name, sql := range rules {
		if _, err := d.Exec(`INSERT INTO pack_query VALUES ('p', 'rule', ?, ?)`, name, sql); err != nil {
			t.Fatal(err)
		}
	}
	return d
}

func strs(t *testing.T, d *db.DB, q string) []string {
	t.Helper()
	rows, err := d.Query(q)
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

func TestCoherenceRejectsEachKindOfBadEdge(t *testing.T) {
	d := setup(t, map[string]string{
		"good":       edge("x://svc", "x://sa", "compute", "credentials", "credential_access", "config", ""),
		"no-src":     edge("x://gone", "x://sa", "compute", "credentials", "credential_access", "config", ""),
		"no-dst":     edge("x://svc", "x://gone", "compute", "credentials", "credential_access", "config", ""),
		"etype":      edge("x://svc", "x://sa", "compute", "credentials", "x-made/up", "config", ""),
		"src-type":   edge("x://svc", "x://sa", "storage", "credentials", "credential_access", "config", ""),
		"dst-type":   edge("x://svc", "x://sa", "compute", "storage", "credential_access", "config", ""),
		"untyped":    edge("x://untyped", "x://sa", "compute", "credentials", "credential_access", "config", ""),
		"endpoints":  edge("x://sa", "x://svc", "credentials", "compute", "credential_access", "config", ""),
		"agent-prov": edge("x://svc", "x://sa", "compute", "credentials", "credential_access", "agent", ""),
	})
	rep, err := Rebuild(context.Background(), d.DB)
	if err != nil {
		t.Fatal(err)
	}
	if len(rep.Failed) > 0 || rep.Edges != 1 || rep.Rejects != 8 {
		t.Fatalf("report = %+v, want 1 edge and 8 rejects", rep)
	}
	got := strs(t, d, `SELECT rule || ': ' || reason FROM edge_reject ORDER BY rule`)
	want := []string{
		"agent-prov: rules may not emit agent provenance",
		"dst-type: dst_type storage is not a type of x/Account",
		"endpoints: credential_access may not join credentials to compute",
		"etype: edge type x-made/up is not declared",
		"no-dst: destination x://gone is not a node",
		"no-src: source x://gone is not a node",
		"src-type: src_type storage is not a type of x/Service",
		"untyped: src_type compute is not a type of x/Unknown",
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("rejects:\n got  %q\n want %q", got, want)
	}
}

func TestConfidenceFromProvenanceAndBasis(t *testing.T) {
	d := setup(t, map[string]string{
		"a-config":   edge("x://svc", "x://sa", "compute", "credentials", "credential_access", "config", ""),
		"b-epss":     edge("caizen://internet", "x://svc", "internet", "compute", "code_execution", "static", `{"epss":0.3,"kev":false}`),
		"c-kev":      edge("caizen://internet", "x://svc", "internet", "compute", "code_execution", "static", `{"epss":0.1,"kev":true}`),
		"d-kev-high": edge("caizen://internet", "x://svc", "internet", "compute", "code_execution", "static", `{"epss":0.95,"kev":true}`),
		"e-no-basis": edge("caizen://internet", "x://svc", "internet", "compute", "code_execution", "static", ""),
		"f-no-epss":  edge("caizen://internet", "x://svc", "internet", "compute", "code_execution", "static", `{"epss":null,"kev":false}`),
	})
	if _, err := Rebuild(context.Background(), d.DB); err != nil {
		t.Fatal(err)
	}
	got := strs(t, d, `SELECT rule || ' ' || exists_confidence || ' ' || traverse_confidence FROM abstract_edge ORDER BY rule`)
	want := []string{
		"a-config 1.0 0.995",
		"b-epss 0.4 0.3",
		"c-kev 0.4 0.9",
		"d-kev-high 0.4 0.95",
		"e-no-basis 0.4 1.0",
		"f-no-epss 0.4 0.0",
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("confidences:\n got  %q\n want %q", got, want)
	}
}

func TestGoalsFromClassValueAndStoragePrior(t *testing.T) {
	d := setup(t, map[string]string{
		"contains": `SELECT 'x://bucket' AS src, 'x://bucket#contents' AS dst, 'storage' AS src_type, 'data' AS dst_type,
			'contains' AS etype, 'p' AS phase, 'config' AS provenance, '{}' AS witness, 'tc' AS truth_condition`,
	})
	if _, err := Rebuild(context.Background(), d.DB); err != nil {
		t.Fatal(err)
	}
	got := strs(t, d, `SELECT node_id || ' ' || value FROM goal ORDER BY node_id`)
	want := []string{"x://bucket#contents 15000", "x://org 100000"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("goals:\n got  %q\n want %q", got, want)
	}
}

func TestFailingRuleDropsOnlyItsOwnEdges(t *testing.T) {
	d := setup(t, map[string]string{
		"good":   edge("x://svc", "x://sa", "compute", "credentials", "credential_access", "config", ""),
		"broken": `SELECT no_such_column FROM node`,
		"enum":   edge("x://svc", "x://sa", "compute", "not-a-type", "credential_access", "config", ""),
	})
	rep, err := Rebuild(context.Background(), d.DB)
	if err != nil {
		t.Fatal(err)
	}
	var failed []string
	for _, f := range rep.Failed {
		failed = append(failed, f.Name)
	}
	if !reflect.DeepEqual(failed, []string{"broken", "enum"}) || rep.Edges != 1 {
		t.Fatalf("failed = %v, edges = %d; want [broken enum] and 1", failed, rep.Edges)
	}
}

func TestDuplicateNodeIDFailsRebuild(t *testing.T) {
	d := setup(t, nil)
	if _, err := d.Exec(`INSERT INTO pack_query VALUES ('q', 'nodes', 'nodes', $$SELECT 'x://svc' AS id, 'x/Service' AS label$$)`); err != nil {
		t.Fatal(err)
	}
	_, err := Rebuild(context.Background(), d.DB)
	if err == nil || !strings.Contains(err.Error(), "node x://svc is emitted more than once, by p, q") {
		t.Fatalf("err = %v, want a duplicate node error", err)
	}
}
