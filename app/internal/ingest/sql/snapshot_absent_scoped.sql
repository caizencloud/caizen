-- As snapshot_absent.sql, but only for rows in the scopes the batch covers.
-- $1: feed_id, $2: batch run.
UPDATE record SET valid_to = greatest(CAST($2 AS TIMESTAMP), valid_from), end_reason = 'absent'
WHERE feed_id = $1 AND valid_to IS NULL
  AND record_id NOT IN (SELECT record_id FROM _checked WHERE record_id IS NOT NULL)
  AND scope IN (SELECT scope FROM _covered)
