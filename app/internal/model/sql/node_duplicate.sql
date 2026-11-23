-- A node ID emitted more than once, with the packs that emitted it.
SELECT id, string_agg(pack_id, ', ' ORDER BY pack_id) FROM node
GROUP BY id HAVING count(*) > 1 ORDER BY id LIMIT 1
