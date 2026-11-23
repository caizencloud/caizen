-- Every capability-gated walk that ends at a goal (ADR-0006, ADR-0007).
-- A walk starts at an edge that requires nothing. A step takes an edge only
-- when the walk already holds what the edge requires, adds what it grants,
-- never revisits a node, and keeps the confidence product above the prune.
-- $1: the most hops in a walk, $2: the prune threshold.
INSERT INTO chain
WITH RECURSIVE
e AS (
    SELECT a.src, a.dst, a.etype, a.pack_id || '/' || a.rule AS rule,
           a.exists_confidence * a.traverse_confidence AS conf, t.requires, t.grants
    FROM abstract_edge a JOIN edge_type t USING (etype)
),
walk(path, etypes, rules, held, confidence) AS (
    SELECT [src, dst], [etype], [rule],
           CASE WHEN grants IS NULL THEN []::capability[] ELSE [grants] END,
           conf
    FROM e
    WHERE requires IS NULL AND conf > $2
    UNION ALL
    SELECT list_append(w.path, e.dst), list_append(w.etypes, e.etype), list_append(w.rules, e.rule),
           CASE WHEN e.grants IS NULL OR list_contains(w.held, e.grants) THEN w.held
                ELSE list_append(w.held, e.grants) END,
           w.confidence * e.conf
    FROM walk w JOIN e ON e.src = w.path[-1]
    WHERE len(w.etypes) < $1
      AND NOT list_contains(w.path, e.dst)
      AND w.confidence * e.conf > $2
      AND (e.requires IS NULL OR list_contains(w.held, e.requires))
)
SELECT w.path, w.etypes, w.rules, w.confidence, g.value, w.confidence * g.value
FROM walk w JOIN goal g ON g.node_id = w.path[-1]
