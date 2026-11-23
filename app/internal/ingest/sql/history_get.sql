-- $1: feed_id.
SELECT history_complete FROM feed_state WHERE feed_id = $1
