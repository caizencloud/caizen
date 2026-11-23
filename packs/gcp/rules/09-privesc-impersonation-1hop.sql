-- rule: 09-privesc-impersonation-1hop
-- intent: a service account can become another service account through
--         any of three routes: mint its token (getAccessToken or signJwt),
--         create a key for it unless iam.disableServiceAccountKeyCreation
--         is enforced on it, or act as it while creating a workload in its
--         project, whose code then reads its token from the metadata
--         server. One edge per pair, with every route in the witness.
-- falsifiers: every route's permissions are revoked; the target service
--             account is deleted or disabled
WITH target AS (
    SELECT s.id, s.project_id, coalesce(c.enforced, false) AS keys_disabled
    FROM gcp_service_account s
    LEFT JOIN gcp_constraint c ON c.resource_id = s.id
                              AND c.constraint_name = 'constraints/iam.disableServiceAccountKeyCreation'
), route AS (
    SELECT g.member_id, t.id AS target, g.permission AS via, g.role, g.granted_on
    FROM gcp_grant g JOIN target t ON t.id = g.resource_id
    WHERE g.permission IN ('iam.serviceAccounts.getAccessToken', 'iam.serviceAccounts.signJwt')
       OR (g.permission = 'iam.serviceAccountKeys.create' AND NOT t.keys_disabled)
    UNION ALL
    SELECT a.member_id, t.id, 'iam.serviceAccounts.actAs + ' || w.permission, a.role, a.granted_on
    FROM gcp_grant a
    JOIN target t ON t.id = a.resource_id
    JOIN gcp_grant w ON w.member_id = a.member_id
                    AND w.resource_id = 'https://cloudresourcemanager.googleapis.com/projects/' || t.project_id
    JOIN gcp_workload_permission wp ON wp.permission = w.permission
    WHERE a.permission = 'iam.serviceAccounts.actAs'
)
SELECT r.member_id AS src, r.target AS dst, 'identity' AS src_type, 'identity' AS dst_type,
       'priv_esc' AS etype, 'privilege_escalation' AS phase, 'T1098' AS tech, '001' AS subtech,
       'Account Manipulation: Additional Cloud Credentials' AS title, 'config' AS provenance,
       json_object('via', list(DISTINCT json_object('permission', r.via, 'role', r.role, 'on', r.granted_on))) AS witness,
       'the source still holds the permissions of at least one route on the target service account' AS truth_condition
FROM route r
JOIN gcp_service_account s ON s.id = r.member_id
WHERE r.member_id <> r.target
GROUP BY r.member_id, r.target
