-- Feeds whose manifest row changed or disappeared since their records loaded.
CREATE OR REPLACE TEMP TABLE _stale AS
SELECT s.feed_id
FROM feed_state s
LEFT JOIN feed_manifest f USING (feed_id)
WHERE f.feed_id IS NULL OR md5(to_json(f)::VARCHAR) <> s.manifest_hash
