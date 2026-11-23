-- $1: batch_id, $2: feed_id.
INSERT INTO reject SELECT $1, $2, line, reason FROM _checked WHERE reason IS NOT NULL
