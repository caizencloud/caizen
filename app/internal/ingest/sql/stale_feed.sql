-- One feed to reset. $1: feed_id.
CREATE OR REPLACE TEMP TABLE _stale AS SELECT $1::VARCHAR AS feed_id
