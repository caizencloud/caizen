-- $1: feed_id.
SELECT records, run FROM ledger
WHERE feed_id = $1 AND status = 'accepted'
ORDER BY run DESC LIMIT 1
