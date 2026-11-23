-- $1: batch_id.
SELECT count(*) FROM batch_accept WHERE batch_id = $1
