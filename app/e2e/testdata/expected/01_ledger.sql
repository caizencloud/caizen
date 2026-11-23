-- The capture holds exactly one batch per feed, and every batch is accepted.
WITH expected(feed_id) AS (VALUES
    ('gcp-cai-resource'), ('gcp-cai-iam-policy'), ('gcp-cai-org-policy'),
    ('oci-image'), ('gcp-aa-vulnerability'), ('gcp-aa-build'), ('gcp-aa-discovery'), ('gcp-aa-package'),
    ('cisa-kev'), ('first-epss'), ('github-api'), ('gcp-iam-role'))
SELECT 'batch not accepted' AS problem, batch_id AS detail FROM ledger WHERE status <> 'accepted'
UNION ALL
SELECT 'feed has no batch', e.feed_id FROM expected e
WHERE NOT EXISTS (SELECT 1 FROM ledger l WHERE l.feed_id = e.feed_id)
UNION ALL
SELECT 'feed has more than one batch', feed_id FROM ledger GROUP BY feed_id HAVING count(*) > 1
UNION ALL
SELECT 'unexpected feed', feed_id FROM ledger WHERE feed_id NOT IN (SELECT feed_id FROM expected)
