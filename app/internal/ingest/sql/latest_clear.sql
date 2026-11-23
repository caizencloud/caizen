-- A latest feed keeps only its newest accepted batch, so the batch's valid
-- records replace every row of the feed (latest_insert.sql).
-- $1: feed_id.
DELETE FROM record WHERE feed_id = $1
