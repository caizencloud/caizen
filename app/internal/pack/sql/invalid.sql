-- The first broken rule across all packs, as (problem, detail), if any.
-- A key declared twice, or a row of the core-owned tables that another pack
-- inserted.
SELECT * FROM (
    SELECT 'feed declared more than once' AS problem, feed_id AS detail
    FROM feed_manifest GROUP BY feed_id HAVING count(*) > 1
    UNION ALL
    SELECT 'edge type declared more than once', etype FROM edge_type GROUP BY etype HAVING count(*) > 1
    UNION ALL
    SELECT 'class value declared more than once', class FROM class_value GROUP BY class HAVING count(*) > 1
    UNION ALL
    SELECT 'node type declared more than once', label FROM node_type GROUP BY label HAVING count(*) > 1
    UNION ALL
    SELECT 'value class declared more than once', label FROM value_class GROUP BY label HAVING count(*) > 1
    UNION ALL
    SELECT 'storage prior declared more than once', label FROM storage_prior GROUP BY label HAVING count(*) > 1
    UNION ALL
    SELECT 'only the core pack may declare edge types', etype FROM edge_type WHERE pack_id <> 'core'
    UNION ALL
    SELECT 'only the core pack may declare edge endpoints', etype FROM edge_endpoint WHERE pack_id <> 'core'
    UNION ALL
    SELECT 'only the core pack may set class values', class FROM class_value WHERE pack_id <> 'core'
    UNION ALL
    SELECT 'value class names a class with no class_value', label || ' -> ' || class
    FROM value_class WHERE class NOT IN (SELECT class FROM class_value)
) ORDER BY problem, detail LIMIT 1
