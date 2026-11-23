-- Views and macros that packs created, as (kind, name).
SELECT 'VIEW', view_name FROM duckdb_views() WHERE NOT internal AND schema_name = 'main'
UNION ALL
SELECT DISTINCT CASE function_type WHEN 'table_macro' THEN 'MACRO TABLE' ELSE 'MACRO' END, function_name
FROM duckdb_functions()
WHERE function_type IN ('macro', 'table_macro') AND NOT internal AND schema_name = 'main'
