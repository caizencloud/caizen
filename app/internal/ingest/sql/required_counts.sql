-- Records failing a required expression, and distinct record IDs.
SELECT count(*) FILTER (WHERE missing IS NOT NULL), count(DISTINCT record_id)
FROM _staged
