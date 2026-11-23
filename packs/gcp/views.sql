-- Ground-plane views over the current CAI, IAM policy, and role records.
-- Node IDs are https: plus the CAI name, with every projects/<number>
-- rewritten to projects/<project-id>. A service account's ID uses its email.

CREATE VIEW gcp_cai AS
SELECT record_id AS name, data->>'$.asset_type' AS asset_type,
       data->'$.resource.data' AS data,
       CAST(data->'$.ancestors' AS VARCHAR[]) AS ancestors
FROM record WHERE feed_id = 'gcp-cai-resource' AND valid_to IS NULL;

CREATE VIEW gcp_project AS
SELECT data->>'$.projectNumber' AS number, data->>'$.projectId' AS project_id
FROM gcp_cai WHERE asset_type = 'cloudresourcemanager.googleapis.com/Project';

-- The node ID of a CAI full resource name. A project number with no
-- Project record stays a number.
CREATE MACRO gcp_id(name) AS 'https:' || coalesce(
    regexp_replace(name, '/projects/[0-9]+(/|$)',
        '/projects/' || (SELECT p.project_id FROM gcp_project p
                         WHERE p.number = regexp_extract(name, '/projects/([0-9]+)(/|$)', 1)) || '\1'),
    name);

-- The node ID of a CAI ancestor such as projects/123 or folders/456.
CREATE MACRO gcp_ancestor_id(a) AS gcp_id('//cloudresourcemanager.googleapis.com/' || a);

CREATE VIEW gcp_service_account AS
SELECT name AS cai_name, lower(data->>'$.email') AS email, data->>'$.projectId' AS project_id,
       'https://iam.googleapis.com/projects/' || (data->>'$.projectId') || '/serviceAccounts/'
           || lower(data->>'$.email') AS id
FROM gcp_cai WHERE asset_type = 'iam.googleapis.com/ServiceAccount';

-- Every current CAI resource with its node ID. label is the asset type.
CREATE VIEW gcp_resource AS
SELECT coalesce(sa.id, gcp_id(c.name)) AS id, c.name, c.asset_type AS label, c.data, c.ancestors
FROM gcp_cai c LEFT JOIN gcp_service_account sa ON sa.cai_name = c.name;

-- The node ID of an IAM member. allUsers and allAuthenticatedUsers are the
-- internet. A service account outside the export keeps Google's projects/-
-- form. deleted: members and the legacy projectEditor:, projectOwner:, and
-- projectViewer: members have no ID here; gcp_binding expands the legacy ones.
CREATE MACRO gcp_member_id(member) AS CASE
    WHEN member IN ('allUsers', 'allAuthenticatedUsers') THEN 'caizen://internet'
    WHEN starts_with(member, 'serviceAccount:') THEN coalesce(
        (SELECT s.id FROM gcp_service_account s WHERE s.email = lower(substr(member, 16))),
        'https://iam.googleapis.com/projects/-/serviceAccounts/' || lower(substr(member, 16)))
    WHEN starts_with(member, 'user:') THEN 'principal://goog/subject/' || lower(substr(member, 6))
    WHEN starts_with(member, 'group:') THEN 'principalSet://goog/group/' || lower(substr(member, 7))
    WHEN starts_with(member, 'domain:') THEN 'principalSet://goog/domain/' || lower(substr(member, 8))
END;

-- Every IAM binding member, on the node its policy is attached to. A legacy
-- bucket member such as projectEditor:<project> expands to the members that
-- hold the matching basic role directly on that project. A conditional
-- binding counts as granted; its condition is kept for witnesses.
CREATE VIEW gcp_binding AS
WITH policy AS (
    SELECT record_id AS name, unnest(CAST(data->'$.iam_policy.bindings' AS JSON[])) AS b
    FROM record WHERE feed_id = 'gcp-cai-iam-policy' AND valid_to IS NULL
), flat AS (
    SELECT name, b->>'$.role' AS role, b->'$.condition' AS condition,
           unnest(CAST(b->'$.members' AS VARCHAR[])) AS member
    FROM policy
), direct AS (
    SELECT coalesce(s.id, gcp_id(f.name)) AS resource_id, f.role, f.member, f.condition,
           gcp_member_id(f.member) AS member_id
    FROM flat f LEFT JOIN gcp_service_account s ON s.cai_name = f.name
)
SELECT resource_id, role, member, member_id, condition FROM direct WHERE member_id IS NOT NULL
UNION ALL
SELECT d.resource_id, d.role, d.member, e.member_id, d.condition
FROM direct d
JOIN direct e
  ON e.resource_id = 'https://cloudresourcemanager.googleapis.com/projects/' || split_part(d.member, ':', 2)
 AND e.role = 'roles/' || CASE split_part(d.member, ':', 1)
                              WHEN 'projectEditor' THEN 'editor'
                              WHEN 'projectOwner' THEN 'owner'
                              WHEN 'projectViewer' THEN 'viewer' END
 AND e.member_id IS NOT NULL
WHERE split_part(d.member, ':', 1) IN ('projectEditor', 'projectOwner', 'projectViewer');

-- Every permission of every role: predefined roles from gcp-iam-role and
-- custom roles from CAI.
CREATE VIEW gcp_role_permission AS
SELECT record_id AS role,
       unnest(CAST(coalesce(data->'$.includedPermissions', '[]') AS VARCHAR[])) AS permission
FROM record WHERE feed_id = 'gcp-iam-role' AND valid_to IS NULL
UNION ALL
SELECT data->>'$.name',
       unnest(CAST(coalesce(data->'$.includedPermissions', '[]') AS VARCHAR[]))
FROM gcp_cai WHERE asset_type = 'iam.googleapis.com/Role';

-- Each resource with itself and every ancestor.
CREATE VIEW gcp_ancestor AS
SELECT id AS resource_id, id AS ancestor_id FROM gcp_resource
UNION
SELECT r.id, gcp_ancestor_id(a) FROM gcp_resource r, unnest(r.ancestors) t(a);

-- Every permission each member holds on each resource, from bindings on the
-- resource or any ancestor. Rules filter it by permission.
CREATE VIEW gcp_grant AS
SELECT b.member_id, rp.permission, a.resource_id, b.resource_id AS granted_on, b.role, b.member, b.condition
FROM gcp_binding b
JOIN gcp_role_permission rp ON rp.role = b.role
JOIN gcp_ancestor a ON a.ancestor_id = b.resource_id;

-- Cloud Run services with their runtime service account and ingress.
CREATE VIEW gcp_run_service AS
SELECT id, name,
       data->>'$.metadata.annotations."run.googleapis.com/ingress"' AS ingress,
       gcp_member_id('serviceAccount:' || (data->>'$.spec.template.spec.serviceAccountName')) AS runtime_sa
FROM gcp_resource WHERE label = 'run.googleapis.com/Service';

-- The image each serving revision of a service runs: every revision in
-- status.traffic with a share above zero.
CREATE VIEW gcp_run_image AS
WITH traffic AS (
    SELECT id AS service_id, name, unnest(CAST(data->'$.status.traffic' AS JSON[])) AS t
    FROM gcp_resource WHERE label = 'run.googleapis.com/Service'
)
SELECT t.service_id, rv.id AS revision_id, 'https://' || (rv.data->>'$.status.imageDigest') AS image_id
FROM traffic t
JOIN gcp_resource rv
  ON rv.label = 'run.googleapis.com/Revision'
 AND rv.name = regexp_replace(t.name, '/services/[^/]+$', '/revisions/' || (t.t->>'$.revisionName'))
WHERE coalesce(TRY_CAST(t.t->>'$.percent' AS INTEGER), 0) > 0;

-- Services that anyone on the internet can invoke: allUsers or
-- allAuthenticatedUsers holds run.routes.invoke and ingress is all.
CREATE VIEW gcp_run_public AS
SELECT s.id AS service_id, s.ingress, list(DISTINCT g.member ORDER BY g.member) AS members
FROM gcp_run_service s
JOIN gcp_grant g ON g.resource_id = s.id AND g.permission = 'run.routes.invoke'
                AND g.member_id = 'caizen://internet'
WHERE s.ingress = 'all'
GROUP BY ALL;

-- Enabled 2nd-gen build triggers with their source repo URL and service
-- account. A disabled trigger runs nothing.
CREATE VIEW gcp_build_trigger AS
SELECT t.id, t.data->'$.repositoryEventConfig' AS event,
       regexp_replace(repo.data->>'$.remoteUri', '\.git$', '') AS repo_id,
       gcp_member_id('serviceAccount:' || split_part(t.data->>'$.serviceAccount', '/serviceAccounts/', 2)) AS sa_id
FROM gcp_resource t
LEFT JOIN gcp_resource repo
  ON repo.label = 'cloudbuild.googleapis.com/Repository'
 AND repo.name = '//cloudbuild.googleapis.com/' || (t.data->>'$.repositoryEventConfig.repository')
WHERE t.label = 'cloudbuild.googleapis.com/BuildTrigger'
  AND NOT coalesce(TRY_CAST(t.data->>'$.disabled' AS BOOLEAN), false);

-- The Artifact Registry repository node ID of an image node ID.
CREATE MACRO gcp_image_repo(image_id) AS regexp_replace(image_id,
    '^https://([a-z0-9-]+)-docker\.pkg\.dev/([^/]+)/([^/]+)/.*$',
    'https://artifactregistry.googleapis.com/projects/\2/locations/\1/repositories/\3');
