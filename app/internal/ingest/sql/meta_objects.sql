-- The object URIs _meta.json lists, or no rows when it lists none.
SELECT unnest(json_extract_string(meta, '$.objects[*]')) FROM _meta
