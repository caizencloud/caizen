-- Every collected image, by node ID (https://<registry>/<path>@sha256:<hex>).
-- oci-image is an event feed, so a digest collected again with new lineage
-- fields has several rows; the newest wins.
CREATE VIEW oci_image AS
SELECT 'https://' || record_id AS id, record_id AS ref,
       CAST(data->'$.config.rootfs.diff_ids' AS VARCHAR[]) AS diff_ids
FROM record WHERE feed_id = 'oci-image' AND valid_to IS NULL
QUALIFY row_number() OVER (PARTITION BY record_id ORDER BY valid_from DESC) = 1;

-- Each image's base: the collected image whose diff_ids are the longest
-- strict prefix of its own. Uncompressed layer IDs survive a push to another
-- registry, and compressed digests do not (PLAN.md, image lineage findings).
CREATE VIEW oci_base AS
SELECT i.id AS image_id, arg_max(b.id, len(b.diff_ids)) AS base_id
FROM oci_image i
JOIN oci_image b ON b.id <> i.id
    AND len(b.diff_ids) < len(i.diff_ids)
    AND i.diff_ids[1:len(b.diff_ids)] = b.diff_ids
GROUP BY i.id;

-- Artifact Analysis vulnerability occurrences, one row per image and CVE.
CREATE VIEW oci_vulnerability AS
SELECT data->>'$.resourceUri' AS image_id,
       regexp_extract(data->>'$.noteName', '/notes/(.+)$', 1) AS cve,
       data->>'$.vulnerability.cvssv3.attackVector' AS attack_vector,
       data->>'$.vulnerability.cvssv3.privilegesRequired' AS privileges_required,
       data->>'$.vulnerability.cvssv3.userInteraction' AS user_interaction,
       data->>'$.vulnerability.effectiveSeverity' AS severity,
       TRY_CAST(data->>'$.vulnerability.cvssScore' AS DOUBLE) AS cvss
FROM record WHERE feed_id = 'gcp-aa-vulnerability' AND valid_to IS NULL;
