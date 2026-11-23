-- Rows in all pack tables, and the rows under one pack. $1: pack_id.
SELECT count(*), count(*) FILTER (WHERE pack_id = $1) FROM (
    SELECT pack_id FROM feed_manifest
    UNION ALL SELECT pack_id FROM edge_type
    UNION ALL SELECT pack_id FROM edge_endpoint
    UNION ALL SELECT pack_id FROM class_value
    UNION ALL SELECT pack_id FROM node_type
    UNION ALL SELECT pack_id FROM value_class
    UNION ALL SELECT pack_id FROM storage_prior
    UNION ALL SELECT pack_id FROM pack_query)
