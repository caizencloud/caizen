-- Remove everything loaded for the feeds in _stale, then give every declared
-- feed without state a fresh row whose history is incomplete.
DELETE FROM record WHERE feed_id IN (SELECT feed_id FROM _stale);
DELETE FROM reject WHERE feed_id IN (SELECT feed_id FROM _stale);
DELETE FROM ledger WHERE feed_id IN (SELECT feed_id FROM _stale);
DELETE FROM feed_state WHERE feed_id IN (SELECT feed_id FROM _stale);
INSERT INTO feed_state
SELECT f.feed_id, md5(to_json(f)::VARCHAR), false
FROM feed_manifest f
WHERE f.feed_id NOT IN (SELECT feed_id FROM feed_state);
DROP TABLE _stale;
