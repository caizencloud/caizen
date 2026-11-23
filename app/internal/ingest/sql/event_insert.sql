-- Append events whose (record_id, data_hash) pair is new.
-- $1: feed_id, $2: batch_id.
INSERT INTO record
SELECT $1, s.record_id, s.valid_from, NULL, NULL, NULL, s.data, s.data_hash, $2
FROM _s s
WHERE NOT EXISTS (SELECT 1 FROM record r
    WHERE r.feed_id = $1 AND r.record_id = s.record_id AND r.data_hash = s.data_hash)
