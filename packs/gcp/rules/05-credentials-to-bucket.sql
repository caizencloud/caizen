-- rule: 05-credentials-to-bucket
-- intent: a service account that holds storage.objects.get on a bucket can
--         read its objects.
-- falsifiers: binding removed; VPC Service Controls block the caller; the
--             objects use a CMEK key the caller cannot use
SELECT g.member_id AS src, g.resource_id AS dst, 'credentials' AS src_type, 'storage' AS dst_type,
       'reads_data' AS etype, 'collection' AS phase, 'T1530' AS tech, NULL AS subtech,
       'Data from Cloud Storage' AS title, 'config' AS provenance,
       json_object('grants', list(DISTINCT json_object('role', g.role, 'on', g.granted_on, 'member', g.member))) AS witness,
       'the service account still holds storage.objects.get on the bucket' AS truth_condition
FROM gcp_grant g
JOIN gcp_service_account s ON s.id = g.member_id
JOIN gcp_resource b ON b.id = g.resource_id AND b.label = 'storage.googleapis.com/Bucket'
WHERE g.permission = 'storage.objects.get'
GROUP BY g.member_id, g.resource_id
