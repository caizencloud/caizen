-- GitHub pages by HTTP status match the capture: 39 successes, 7 forbidden
-- (branch protection and rulesets need GitHub Pro; org hooks need a token
-- permission), and 9 not found.
WITH expected(status, n) AS (VALUES ('200', 39), ('403', 7), ('404', 9)),
actual AS (SELECT data->>'$.status' AS status, count(*) AS n
           FROM record WHERE feed_id = 'github-api' GROUP BY 1)
SELECT e.*, a.n AS actual FROM expected e FULL JOIN actual a USING (status)
WHERE e.n IS DISTINCT FROM a.n
