-- Open rows for new, changed, and returning records.
-- $1: feed_id, $2: batch_id.
INSERT INTO record
SELECT $1, record_id, eff, NULL, NULL, scope, data, data_hash, $2
FROM _eff WHERE open_hash IS NULL OR open_hash <> data_hash
