-- Each valid record with its open row's hash and the time a new row would
-- start: the record's valid_from when it is later than the end of the
-- record's previous row, otherwise the later of the batch time and that end.
-- Rows of one record therefore never overlap.
-- $1: feed_id, $2: batch run.
CREATE OR REPLACE TEMP TABLE _eff AS
SELECT s.*, o.data_hash AS open_hash,
       CASE WHEN p.prev IS NULL OR s.valid_from > p.prev THEN s.valid_from
            ELSE greatest(CAST($2 AS TIMESTAMP), p.prev) END AS eff
FROM _s s
LEFT JOIN (SELECT record_id, max(coalesce(valid_to, valid_from)) AS prev
           FROM record WHERE feed_id = $1 GROUP BY record_id) p USING (record_id)
LEFT JOIN (SELECT record_id, data_hash
           FROM record WHERE feed_id = $1 AND valid_to IS NULL) o USING (record_id)
