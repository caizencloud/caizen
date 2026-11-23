-- rule: 21-identity-administers-control-plane
-- intent: a service account that can set the IAM policy of an organization,
--         folder, or project can grant itself any role there.
-- falsifiers: the permission is revoked; an org policy restricts which
--             members a policy may name
SELECT g.member_id AS src, g.resource_id AS dst, 'identity' AS src_type, 'control_plane' AS dst_type,
       'priv_esc' AS etype, 'privilege_escalation' AS phase, 'T1098' AS tech, '003' AS subtech,
       'Account Manipulation: Additional Cloud Roles' AS title, 'config' AS provenance,
       json_object('grants', list(DISTINCT json_object('permission', g.permission, 'role', g.role, 'on', g.granted_on))) AS witness,
       'the service account still holds setIamPolicy on the node' AS truth_condition
FROM gcp_grant g
JOIN gcp_service_account s ON s.id = g.member_id
JOIN gcp_resource n ON n.id = g.resource_id
WHERE (n.label, g.permission) IN (
    ('cloudresourcemanager.googleapis.com/Organization', 'resourcemanager.organizations.setIamPolicy'),
    ('cloudresourcemanager.googleapis.com/Folder',       'resourcemanager.folders.setIamPolicy'),
    ('cloudresourcemanager.googleapis.com/Project',      'resourcemanager.projects.setIamPolicy'))
GROUP BY g.member_id, g.resource_id
