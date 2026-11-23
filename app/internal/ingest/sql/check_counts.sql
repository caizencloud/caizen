-- Distinct record IDs in the batch, valid or not, and rejected lines.
SELECT count(DISTINCT record_id) FILTER (WHERE record_id IS NOT NULL),
       count(*) FILTER (WHERE reason IS NOT NULL)
FROM _checked
