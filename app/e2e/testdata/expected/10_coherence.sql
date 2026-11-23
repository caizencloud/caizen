-- Every rule edge passes the coherence checks, and no rule emits the same
-- edge twice, which would count every chain through it twice.
SELECT pack_id || '/' || rule AS problem, src || ' > ' || dst || ': ' || reason AS detail FROM edge_reject
UNION ALL
SELECT pack_id || '/' || rule, src || ' > ' || dst || ': emitted ' || count(*) || ' times'
FROM abstract_edge GROUP BY pack_id, rule, src, dst HAVING count(*) > 1
