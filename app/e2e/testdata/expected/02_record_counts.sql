-- Open records per feed equal the record counts in the captured raw files.
WITH expected(feed_id, n) AS (VALUES
    ('gcp-cai-resource', 262), ('gcp-cai-iam-policy', 21), ('gcp-cai-org-policy', 1),
    ('oci-image', 2), ('gcp-aa-vulnerability', 526), ('gcp-aa-build', 6),
    ('gcp-aa-discovery', 2), ('gcp-aa-package', 226),
    ('cisa-kev', 1786), ('first-epss', 257), ('github-api', 55)),
actual AS (SELECT feed_id, count(*) AS n FROM record WHERE valid_to IS NULL GROUP BY feed_id)
SELECT e.feed_id, e.n AS expected, a.n AS actual
FROM expected e FULL JOIN actual a USING (feed_id)
WHERE e.n IS DISTINCT FROM a.n
UNION ALL
SELECT feed_id, NULL, count(*) FROM record WHERE valid_to IS NOT NULL GROUP BY feed_id
