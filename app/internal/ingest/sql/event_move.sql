-- A late batch with an earlier run takes over rows it also carries, so the
-- row belongs to the earliest batch by run, as a replay in run order gives.
-- $1: feed_id, $2: batch_id, $3: batch run.
UPDATE record SET valid_from = s.valid_from, batch_id = $2
FROM _s s, ledger l
WHERE record.feed_id = $1 AND record.record_id = s.record_id
  AND record.data_hash = s.data_hash
  AND l.batch_id = record.batch_id AND l.run > CAST($3 AS TIMESTAMP)
