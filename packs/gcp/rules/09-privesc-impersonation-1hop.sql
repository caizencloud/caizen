-- rule: 09-privesc-impersonation-1hop
-- intent: a service account that can create keys for another service
--         account, or act as it and start a build in its project, can
--         become it.
-- falsifiers: the permissions are revoked; an org policy blocks key
--             creation; the target service account is deleted
WITH path AS (
    SELECT g.member_id, t.id AS target, 'iam.serviceAccountKeys.create' AS via, g.role, g.granted_on
    FROM gcp_grant g JOIN gcp_service_account t ON t.id = g.resource_id
    WHERE g.permission = 'iam.serviceAccountKeys.create'
    UNION ALL
    SELECT a.member_id, t.id, 'iam.serviceAccounts.actAs + cloudbuild.builds.create', a.role, a.granted_on
    FROM gcp_grant a
    JOIN gcp_service_account t ON t.id = a.resource_id
    JOIN gcp_grant b ON b.member_id = a.member_id AND b.permission = 'cloudbuild.builds.create'
                    AND b.resource_id = 'https://cloudresourcemanager.googleapis.com/projects/' || t.project_id
    WHERE a.permission = 'iam.serviceAccounts.actAs'
)
SELECT p.member_id AS src, p.target AS dst, 'identity' AS src_type, 'identity' AS dst_type,
       'priv_esc' AS etype, 'privilege_escalation' AS phase, 'T1098' AS tech, '001' AS subtech,
       'Account Manipulation: Additional Cloud Credentials' AS title, 'config' AS provenance,
       json_object('via', list(DISTINCT json_object('permission', p.via, 'role', p.role, 'on', p.granted_on))) AS witness,
       'the source still holds one of these permissions on the target service account' AS truth_condition
FROM path p
JOIN gcp_service_account s ON s.id = p.member_id
WHERE p.member_id <> p.target
GROUP BY p.member_id, p.target
