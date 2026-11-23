-- rule: 02-run-holds-credentials
-- intent: code running in a Cloud Run service can read its runtime service
--         account's token from the metadata server. Cloud Run tokens always
--         carry the cloud-platform scope, so no scope check applies.
-- falsifiers: service deleted; runtime service account changed
SELECT s.id AS src, s.runtime_sa AS dst, 'compute' AS src_type, 'credentials' AS dst_type,
       'credential_access' AS etype, 'credential_access' AS phase, 'T1552' AS tech, '005' AS subtech,
       'Unsecured Credentials: Cloud Instance Metadata API' AS title, 'config' AS provenance,
       json_object('service', s.name, 'service_account', s.runtime_sa) AS witness,
       'the service still runs as this service account' AS truth_condition
FROM gcp_run_service s
WHERE s.runtime_sa IS NOT NULL
