-- Artifact Analysis records carry the image reference as their scope, and
-- split between the api image (98558f12...) and its python base
-- (97ef2d58...) as in the raw files.
WITH expected(feed_id, digest12, n) AS (VALUES
    ('gcp-aa-vulnerability', '98558f122fb7', 263), ('gcp-aa-vulnerability', '97ef2d5864e5', 263),
    ('gcp-aa-package', '98558f122fb7', 120), ('gcp-aa-package', '97ef2d5864e5', 106),
    ('gcp-aa-build', '98558f122fb7', 3), ('gcp-aa-build', '97ef2d5864e5', 3),
    ('gcp-aa-discovery', '98558f122fb7', 1), ('gcp-aa-discovery', '97ef2d5864e5', 1)),
actual AS (
    SELECT feed_id, substr(split_part(scope, '@sha256:', 2), 1, 12) AS digest12, count(*) AS n
    FROM record WHERE feed_id LIKE 'gcp-aa-%' AND valid_to IS NULL GROUP BY ALL)
SELECT e.*, a.n AS actual FROM expected e FULL JOIN actual a USING (feed_id, digest12)
WHERE e.n IS DISTINCT FROM a.n
UNION ALL
SELECT feed_id, scope, NULL, NULL FROM record
WHERE feed_id LIKE 'gcp-aa-%' AND scope NOT LIKE 'https://us-central1-docker.pkg.dev/%@sha256:%'
