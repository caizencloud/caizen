-- Open rows for every valid record of a latest feed's batch.
-- $1: feed_id, $2: batch_id.
INSERT INTO record
SELECT $1, record_id, valid_from, NULL, NULL, NULL, data, data_hash, $2 FROM _s
