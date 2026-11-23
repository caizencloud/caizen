-- Close open rows whose record changed. $1: feed_id.
UPDATE record SET valid_to = e.eff, end_reason = 'changed'
FROM _eff e
WHERE record.feed_id = $1 AND record.valid_to IS NULL
  AND record.record_id = e.record_id AND e.open_hash <> e.data_hash
