-- $1: batch_id.
INSERT INTO batch_accept
SELECT $1 WHERE NOT EXISTS (SELECT 1 FROM batch_accept WHERE batch_id = $1)
