-- Copies of one record_id with different data are all rejected.
UPDATE _checked SET reason = 'conflicting duplicate identity'
WHERE reason IS NULL AND record_id IN (
    SELECT record_id FROM _checked WHERE reason IS NULL
    GROUP BY record_id HAVING count(DISTINCT data_hash) > 1)
