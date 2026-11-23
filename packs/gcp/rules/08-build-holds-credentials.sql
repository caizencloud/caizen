-- rule: 08-build-holds-credentials
-- intent: code running in a build that a trigger starts can use the
--         trigger's service account.
-- falsifiers: trigger deleted; trigger service account changed
SELECT t.id AS src, t.sa_id AS dst, 'compute' AS src_type, 'credentials' AS dst_type,
       'credential_access' AS etype, 'credential_access' AS phase, 'T1552' AS tech, '005' AS subtech,
       'Unsecured Credentials: Cloud Instance Metadata API' AS title, 'config' AS provenance,
       json_object('trigger', t.id, 'service_account', t.sa_id) AS witness,
       'the trigger still runs builds as this service account' AS truth_condition
FROM gcp_build_trigger t
WHERE t.sa_id IS NOT NULL
