-- Attack paths 1 to 4 from the lonimbus plan appear as chains, node for
-- node. The capture has org_admin_path_enabled on, so path 4 is present.
-- Path 3 replaces the api's base image, so its third hop must come from
-- the base-image rule. The org is worth the class value of an org.
WITH n(k, id) AS (VALUES
    ('internet',      'caizen://internet'),
    ('api',           'https://run.googleapis.com/projects/ln-prod-web/locations/us-central1/services/api'),
    ('api_sa',        'https://iam.googleapis.com/projects/ln-prod-web/serviceAccounts/api-sa@ln-prod-web.iam.gserviceaccount.com'),
    ('exports',       'https://storage.googleapis.com/ln-prod-web-customer-exports'),
    ('contents',      'https://storage.googleapis.com/ln-prod-web-customer-exports#contents'),
    ('api_repo',      'https://github.com/lonimbus/api'),
    ('api_trigger',   'https://cloudbuild.googleapis.com/projects/ln-prod-web/locations/us-central1/triggers/4f10987a-0121-48ea-92ed-1c7377825ee8'),
    ('api_build_sa',  'https://iam.googleapis.com/projects/ln-prod-web/serviceAccounts/api-build-sa@ln-prod-web.iam.gserviceaccount.com'),
    ('base_repo',     'https://github.com/lonimbus/base-images'),
    ('base_trigger',  'https://cloudbuild.googleapis.com/projects/ln-prod-automation/locations/us-central1/triggers/e81a7dcd-2acd-4992-8e42-b71e202f729a'),
    ('base_build_sa', 'https://iam.googleapis.com/projects/ln-prod-automation/serviceAccounts/base-build-sa@ln-prod-automation.iam.gserviceaccount.com'),
    ('terraform_sa',  'https://iam.googleapis.com/projects/ln-prod-automation/serviceAccounts/terraform-sa@ln-prod-automation.iam.gserviceaccount.com'),
    ('org',           'https://cloudresourcemanager.googleapis.com/organizations/684587186245')),
expected(name, keys) AS (VALUES
    ('path 1', ['internet', 'api', 'api_sa', 'exports', 'contents']),
    ('path 2', ['api_repo', 'api_trigger', 'api_build_sa', 'api', 'api_sa', 'exports', 'contents']),
    ('path 3', ['base_repo', 'base_trigger', 'base_build_sa', 'api', 'api_sa', 'exports', 'contents']),
    ('path 4', ['base_repo', 'base_trigger', 'base_build_sa', 'terraform_sa', 'org'])),
hops AS (
    SELECT name, unnest(keys) AS k, generate_subscripts(keys, 1) AS i FROM expected),
paths AS (
    SELECT h.name, list(n.id ORDER BY h.i) AS path FROM hops h JOIN n USING (k) GROUP BY h.name)
SELECT p.name AS problem, 'no chain follows this path' AS detail FROM paths p
WHERE NOT EXISTS (SELECT 1 FROM chain c WHERE c.path = p.path)
UNION ALL
SELECT 'path 3', 'hop 3 is not from the base-image rule' FROM paths p
WHERE p.name = 'path 3' AND NOT EXISTS (
    SELECT 1 FROM chain c WHERE c.path = p.path AND c.rules[3] = 'gcp/20-base-image-poisoning')
UNION ALL
SELECT 'path 4', 'the org is not a goal worth 100000' FROM n
WHERE n.k = 'org' AND NOT EXISTS (SELECT 1 FROM goal g WHERE g.node_id = n.id AND g.value = 100000)
