-- $1: batch_id, $2: feed_id.
INSERT INTO reject
SELECT $1, $2, line, 'missing required foreign ID: ' || missing
FROM _staged WHERE missing IS NOT NULL
