-- $1: feed_id, $2: history_complete.
UPDATE feed_state SET history_complete = $2 WHERE feed_id = $1
