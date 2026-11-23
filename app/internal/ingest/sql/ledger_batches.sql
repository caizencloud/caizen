-- $1: feed_id.
SELECT batch_id FROM ledger WHERE feed_id = $1
