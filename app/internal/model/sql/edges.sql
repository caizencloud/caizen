-- Checks every rule edge (ADR-0016) and sets the confidence of each edge
-- that passes. The first failing check is the reject reason.
CREATE OR REPLACE TEMP TABLE _checked AS
SELECT e.*, t.traverse AS type_traverse,
       CASE
           WHEN s.id IS NULL THEN 'source ' || e.src || ' is not a node'
           WHEN d.id IS NULL THEN 'destination ' || e.dst || ' is not a node'
           WHEN t.etype IS NULL THEN 'edge type ' || e.etype || ' is not declared'
           WHEN NOT list_contains(coalesce(s.abstract_types, []), e.src_type)
               THEN 'src_type ' || e.src_type || ' is not a type of ' || s.label
           WHEN NOT list_contains(coalesce(d.abstract_types, []), e.dst_type)
               THEN 'dst_type ' || e.dst_type || ' is not a type of ' || d.label
           WHEN p.etype IS NULL
               THEN e.etype || ' may not join ' || e.src_type || ' to ' || e.dst_type
           WHEN e.provenance = 'agent' THEN 'rules may not emit agent provenance'
       END AS reason
FROM rule_edge e
LEFT JOIN node s ON s.id = e.src
LEFT JOIN node d ON d.id = e.dst
LEFT JOIN edge_type t ON t.etype = e.etype
LEFT JOIN edge_endpoint p ON p.etype = e.etype AND p.src_type = e.src_type AND p.dst_type = e.dst_type;

DELETE FROM edge_reject;
INSERT INTO edge_reject
SELECT pack_id, rule, src, dst, etype, reason FROM _checked WHERE reason IS NOT NULL;

-- A config edge exists with certainty, and its traverse confidence is its
-- edge type's. A scanner (static) edge is a candidate at 0.4 (rules.md).
-- Its traverse confidence comes from its basis: the highest EPSS score of
-- its CVEs, raised to 0.9 when any of them is in CISA KEV.
DELETE FROM abstract_edge;
INSERT INTO abstract_edge
SELECT pack_id, rule, src, dst, src_type, dst_type, etype, phase, tech, subtech, title,
       provenance, witness, truth_condition,
       CASE provenance WHEN 'config' THEN 1.0 ELSE 0.4 END,
       CASE WHEN provenance = 'static' AND basis IS NOT NULL
            THEN greatest(coalesce(TRY_CAST(basis->>'$.epss' AS DOUBLE), 0),
                          CASE WHEN TRY_CAST(basis->>'$.kev' AS BOOLEAN) THEN 0.9 ELSE 0 END)
            ELSE type_traverse END
FROM _checked WHERE reason IS NULL;

DROP TABLE _checked;

-- A goal's value is the class value of its label, or, for the unexamined
-- contents of a container, the storage prior of the container's label.
DELETE FROM goal;
INSERT INTO goal
SELECT node_id, max(value) FROM (
    SELECT n.id AS node_id, cv.value
    FROM node n JOIN value_class vc USING (label) JOIN class_value cv USING (class)
    UNION ALL
    SELECT a.dst, sp.value
    FROM abstract_edge a
    JOIN node c ON c.id = a.src
    JOIN node n ON n.id = a.dst
    JOIN storage_prior sp ON sp.label = c.label
    WHERE a.etype = 'contains' AND n.label = 'caizen/UnscannedContents'
) GROUP BY node_id;
