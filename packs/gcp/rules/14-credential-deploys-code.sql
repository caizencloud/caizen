-- rule: 14-credential-deploys-code
-- intent: a service account that can update a Cloud Run service and act as
--         the service's runtime service account can deploy any code to run
--         as that service.
-- falsifiers: run.services.update or actAs revoked; Binary Authorization
--             requires a signed image; an org policy pins allowed images
SELECT u.member_id AS src, s.id AS dst, 'credentials' AS src_type, 'compute' AS dst_type,
       'use_credential' AS etype, 'execution' AS phase, 'T1648' AS tech, NULL AS subtech,
       'Serverless Execution' AS title, 'config' AS provenance,
       json_object('update', list(DISTINCT json_object('role', u.role, 'on', u.granted_on)),
                   'act_as', list(DISTINCT json_object('role', a.role, 'on', a.granted_on)),
                   'runtime_service_account', s.runtime_sa) AS witness,
       'the service account still holds run.services.update on the service AND iam.serviceAccounts.actAs on its runtime service account' AS truth_condition
FROM gcp_run_service s
JOIN gcp_grant u ON u.resource_id = s.id AND u.permission = 'run.services.update'
JOIN gcp_grant a ON a.resource_id = s.runtime_sa AND a.permission = 'iam.serviceAccounts.actAs'
                AND a.member_id = u.member_id
JOIN gcp_service_account sa ON sa.id = u.member_id
GROUP BY u.member_id, s.id, s.runtime_sa
