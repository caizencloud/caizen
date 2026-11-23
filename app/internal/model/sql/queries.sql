-- Each pack's nodes.sql and rules, nodes first.
SELECT pack_id, kind, name, sql FROM pack_query ORDER BY kind, pack_id, name
