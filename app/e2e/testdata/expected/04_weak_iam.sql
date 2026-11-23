-- The deliberately weak IAM grants from the lonimbus plan are present:
-- base-build-sa holds roles/editor on ln-prod-automation (project number
-- 459462137144), and terraform-sa holds three admin roles on the org.
WITH bindings AS (
    SELECT r.record_id, b->>'$.role' AS role, m AS member
    FROM record r,
         unnest(CAST(r.data->'$.iam_policy.bindings' AS JSON[])) AS t(b),
         unnest(CAST(b->'$.members' AS VARCHAR[])) AS u(m)
    WHERE r.feed_id = 'gcp-cai-iam-policy' AND r.valid_to IS NULL),
expected(record_id, role, member) AS (VALUES
    ('//cloudresourcemanager.googleapis.com/projects/459462137144', 'roles/editor',
     'serviceAccount:base-build-sa@ln-prod-automation.iam.gserviceaccount.com'),
    ('//cloudresourcemanager.googleapis.com/organizations/684587186245', 'roles/resourcemanager.organizationAdmin',
     'serviceAccount:terraform-sa@ln-prod-automation.iam.gserviceaccount.com'),
    ('//cloudresourcemanager.googleapis.com/organizations/684587186245', 'roles/resourcemanager.folderAdmin',
     'serviceAccount:terraform-sa@ln-prod-automation.iam.gserviceaccount.com'),
    ('//cloudresourcemanager.googleapis.com/organizations/684587186245', 'roles/orgpolicy.policyAdmin',
     'serviceAccount:terraform-sa@ln-prod-automation.iam.gserviceaccount.com'))
SELECT * FROM expected EXCEPT SELECT * FROM bindings
