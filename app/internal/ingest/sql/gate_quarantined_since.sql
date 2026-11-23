-- The newest quarantined batch after the last accepted one.
-- $1: feed_id, $2: run of the last accepted batch.
SELECT batch_id, records FROM ledger
WHERE feed_id = $1 AND status = 'quarantined' AND run > CAST($2 AS TIMESTAMP)
ORDER BY run DESC LIMIT 1
