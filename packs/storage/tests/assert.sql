-- Rule 16 behaves as its intent line says (ADR-0020 §6). Every container
-- whose label has a storage prior gets exactly one contains edge to its
-- #contents node, and the node is a goal worth the prior. The fixture holds
-- one project with a bucket and an image repository, which have priors,
-- and a log bucket and a secret, which have none.
WITH n(k, id) AS (VALUES
    ('bucket', 'https://storage.googleapis.com/acme-store-assets'),
    ('repo',   'https://artifactregistry.googleapis.com/projects/acme-store/locations/us-central1/repositories/images'),
    ('logs',   'https://logging.googleapis.com/projects/acme-store/locations/global/buckets/_Default'),
    ('secret', 'https://secretmanager.googleapis.com/projects/acme-store/secrets/api-key')),
e(k, want, value, why) AS (VALUES
    ('bucket', true,  15000, 'storage.googleapis.com/Bucket has a prior of 15000'),
    ('repo',   true,  500,   'artifactregistry.googleapis.com/Repository has a prior of 500'),
    ('logs',   false, NULL,  'a log bucket is a container, but its label has no prior'),
    ('secret', false, NULL,  'secretmanager.googleapis.com/Secret has no prior')),
r AS (SELECT e.*, n.id FROM e JOIN n USING (k))
SELECT 'fixture node is missing' AS problem, r.k || ': ' || r.id AS detail
FROM r WHERE NOT EXISTS (SELECT 1 FROM node WHERE node.id = r.id)
UNION ALL
SELECT 'container has no contains edge to its #contents', r.k || ': ' || r.why
FROM r WHERE r.want AND NOT EXISTS (
    SELECT 1 FROM abstract_edge a
    WHERE a.pack_id = 'storage' AND a.rule = '16-storage-unscanned-contents'
      AND a.src = r.id AND a.dst = r.id || '#contents' AND a.etype = 'contains')
UNION ALL
SELECT 'container without a prior has a contains edge', r.k || ': ' || r.why
FROM r JOIN rule_edge a ON a.rule = '16-storage-unscanned-contents' AND a.src = r.id
WHERE NOT r.want
UNION ALL
SELECT '#contents goal value is wrong', r.k || ' want ' || coalesce(r.value::VARCHAR, 'no goal') || ', got '
       || coalesce(g.value::VARCHAR, 'no goal')
FROM r LEFT JOIN goal g ON g.node_id = r.id || '#contents'
WHERE g.value IS DISTINCT FROM r.value
UNION ALL
-- One edge per container, over every node whose label has a prior, and
-- nothing else.
SELECT 'container does not have exactly one contains edge', c.id || ': ' || count(a.src)
FROM node c JOIN storage_prior p ON p.label = c.label
LEFT JOIN rule_edge a ON a.rule = '16-storage-unscanned-contents' AND a.src = c.id AND a.dst = c.id || '#contents'
GROUP BY c.id HAVING count(a.src) <> 1
UNION ALL
SELECT 'rule 16 edge from a container without a prior', a.src || ' > ' || a.dst
FROM rule_edge a LEFT JOIN node c ON c.id = a.src LEFT JOIN storage_prior p ON p.label = c.label
WHERE a.rule = '16-storage-unscanned-contents' AND p.label IS NULL
UNION ALL
SELECT 'edge rejected: ' || reason, rule || ': ' || src || ' > ' || dst FROM edge_reject
UNION ALL
SELECT 'record rejected by ingest', batch_id || ': ' || reason FROM reject
