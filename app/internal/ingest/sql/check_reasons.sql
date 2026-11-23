-- Mark single bad records. $1: whether the feed is scoped.
CREATE OR REPLACE TEMP TABLE _checked AS
SELECT *, CASE
    WHEN record_id IS NULL THEN 'null identity'
    WHEN valid_from IS NULL THEN 'valid_from is missing or not a timestamp'
    WHEN $1 AND scope IS NULL THEN 'null scope'
END AS reason
FROM _staged
