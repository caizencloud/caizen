-- GitHub pages by HTTP status match the capture, taken on the Team plan: 42
-- successes, 1 forbidden (org hooks need a token permission), and 12 not
-- found (6 CODEOWNERS and workflow paths, and branch protection on the 3
-- repos' main branches, which have none).
WITH expected(status, n) AS (VALUES ('200', 42), ('403', 1), ('404', 12)),
actual AS (SELECT data->>'$.status' AS status, count(*) AS n
           FROM record WHERE feed_id = 'github-api' GROUP BY 1)
SELECT e.*, a.n AS actual FROM expected e FULL JOIN actual a USING (status)
WHERE e.n IS DISTINCT FROM a.n
