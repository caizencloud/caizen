-- All feed rows, and the rows under one pack. : pack_id.
SELECT count(*), count(*) FILTER (WHERE pack_id = $1) FROM feed_manifest
