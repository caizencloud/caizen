-- Current EPSS score of every published CVE.
CREATE VIEW vulnintel_epss AS
SELECT record_id AS cve,
       TRY_CAST(data->>'$.epss' AS DOUBLE) AS epss,
       TRY_CAST(data->>'$.percentile' AS DOUBLE) AS percentile
FROM record WHERE feed_id = 'first-epss' AND valid_to IS NULL;

-- CVEs in the current CISA Known Exploited Vulnerabilities catalog.
CREATE VIEW vulnintel_kev AS
SELECT record_id AS cve, data->>'$.dateAdded' AS date_added
FROM record WHERE feed_id = 'cisa-kev' AND valid_to IS NULL;
