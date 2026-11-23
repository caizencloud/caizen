-- Whether _meta.json exists (one row) and whether its objects is a list.
SELECT count(*), coalesce(bool_or(json_type(meta, '$.objects') = 'ARRAY'), false) FROM _meta
