-- One row per valid record_id; identical copies collapse.
CREATE OR REPLACE TEMP TABLE _s AS
SELECT DISTINCT ON (record_id) record_id, valid_from, scope, data, data_hash
FROM _checked WHERE reason IS NULL
ORDER BY record_id, valid_from
