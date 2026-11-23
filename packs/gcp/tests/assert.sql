-- The gcp rules behave as their intent lines say (ADR-0020 §6). The fixture
-- is a small invented org, acme.test, with three projects: acme-web (Cloud
-- Run services, their SAs, a bucket, and the apps image repo), acme-ops
-- (CI, IAM admins, and the base and tools image repos), and acme-data (a
-- bucket whose readers come only from legacy project members). Each row of
-- e is one expectation. want = true requires the edge; want = false forbids
-- it, and '*' matches any node. Every rule has at least one forbidden edge
-- that is a near miss of an allowed one.
WITH n(k, id) AS (VALUES
    ('internet',       'caizen://internet'),
    ('org',            'https://cloudresourcemanager.googleapis.com/organizations/100000000001'),
    ('folder',         'https://cloudresourcemanager.googleapis.com/folders/200000000001'),
    ('p_web',          'https://cloudresourcemanager.googleapis.com/projects/acme-web'),
    ('p_ops',          'https://cloudresourcemanager.googleapis.com/projects/acme-ops'),
    ('p_data',         'https://cloudresourcemanager.googleapis.com/projects/acme-data'),
    ('web',            'https://run.googleapis.com/projects/acme-web/locations/us-central1/services/web'),
    ('shop',           'https://run.googleapis.com/projects/acme-web/locations/us-central1/services/shop'),
    ('intra',          'https://run.googleapis.com/projects/acme-web/locations/us-central1/services/intra'),
    ('blog',           'https://run.googleapis.com/projects/acme-web/locations/us-central1/services/blog'),
    ('priv',           'https://run.googleapis.com/projects/acme-web/locations/us-central1/services/priv'),
    ('web_sa',         'https://iam.googleapis.com/projects/acme-web/serviceAccounts/web-sa@acme-web.iam.gserviceaccount.com'),
    ('shop_sa',        'https://iam.googleapis.com/projects/acme-web/serviceAccounts/shop-sa@acme-web.iam.gserviceaccount.com'),
    ('old_sa',         'https://iam.googleapis.com/projects/acme-web/serviceAccounts/old-sa@acme-web.iam.gserviceaccount.com'),
    ('build_sa',       'https://iam.googleapis.com/projects/acme-web/serviceAccounts/build-sa@acme-web.iam.gserviceaccount.com'),
    ('half_sa',        'https://iam.googleapis.com/projects/acme-web/serviceAccounts/half-sa@acme-web.iam.gserviceaccount.com'),
    ('keys_sa',        'https://iam.googleapis.com/projects/acme-ops/serviceAccounts/keys-sa@acme-ops.iam.gserviceaccount.com'),
    ('ci_sa',          'https://iam.googleapis.com/projects/acme-ops/serviceAccounts/ci-sa@acme-ops.iam.gserviceaccount.com'),
    ('admin_sa',       'https://iam.googleapis.com/projects/acme-ops/serviceAccounts/admin-sa@acme-ops.iam.gserviceaccount.com'),
    ('auditor_sa',     'https://iam.googleapis.com/projects/acme-ops/serviceAccounts/auditor-sa@acme-ops.iam.gserviceaccount.com'),
    ('projadmin_sa',   'https://iam.googleapis.com/projects/acme-ops/serviceAccounts/projadmin-sa@acme-ops.iam.gserviceaccount.com'),
    ('editor_sa',      'https://iam.googleapis.com/projects/acme-data/serviceAccounts/editor-sa@acme-data.iam.gserviceaccount.com'),
    ('analyst',        'principal://goog/subject/analyst@acme.test'),
    ('exports',        'https://storage.googleapis.com/acme-web-exports'),
    ('exports_c',      'https://storage.googleapis.com/acme-web-exports#contents'),
    ('lake',           'https://storage.googleapis.com/acme-data-lake'),
    ('repo_web',       'https://github.com/acmeco/web'),
    ('repo_ops',       'https://github.com/acmeco/ops'),
    ('repo_docs',      'https://github.com/acmeco/docs'),
    ('repo_legacy',    'https://github.com/acmeco/legacy'),
    ('trg_web',        'https://cloudbuild.googleapis.com/projects/acme-web/locations/us-central1/triggers/11111111-aaaa-4000-8000-000000000001'),
    ('trg_ops',        'https://cloudbuild.googleapis.com/projects/acme-ops/locations/us-central1/triggers/11111111-aaaa-4000-8000-000000000002'),
    ('trg_manual',     'https://cloudbuild.googleapis.com/projects/acme-ops/locations/us-central1/triggers/11111111-aaaa-4000-8000-000000000003'),
    ('trg_legacy',     'https://cloudbuild.googleapis.com/projects/acme-ops/locations/us-central1/triggers/11111111-aaaa-4000-8000-000000000004')),
e(rule, src, dst, want, why) AS (VALUES
    ('01-internet-to-run', 'internet', 'web',   true,  'allUsers holds run.routes.invoke and ingress is all'),
    ('01-internet-to-run', 'internet', 'shop',  true,  'allAuthenticatedUsers holds run.routes.invoke and ingress is all'),
    ('01-internet-to-run', 'internet', 'blog',  true,  'allUsers holds run.routes.invoke and ingress is all'),
    ('01-internet-to-run', 'internet', 'intra', false, 'allUsers is an invoker but ingress is internal'),
    ('01-internet-to-run', 'internet', 'priv',  false, 'ingress is all but allUsers holds only run.viewer, and the invoker is a user'),

    ('02-run-holds-credentials', 'web',  'web_sa',  true,  'web runs as web-sa'),
    ('02-run-holds-credentials', 'shop', 'shop_sa', true,  'shop runs as shop-sa'),
    ('02-run-holds-credentials', 'web',  'old_sa',  false, 'old-sa ran only the retired revision; the service now runs as web-sa'),

    ('03-anon-exploits-public-run', 'internet', 'web',   true,  'public, serving an image with network/no-UI CVEs'),
    ('03-anon-exploits-public-run', 'internet', 'shop',  true,  'public, serving an image with a network/no-UI CVE in KEV'),
    ('03-anon-exploits-public-run', 'internet', 'intra', false, 'serving a network/no-UI CVE but ingress is internal'),
    ('03-anon-exploits-public-run', 'internet', 'blog',  false, 'public, but its CVEs need local access or user interaction'),
    ('03-anon-exploits-public-run', 'internet', 'priv',  false, 'not public and serves no image'),

    ('05-credentials-to-bucket', 'web_sa',    'exports', true,  'storage.objectViewer on the bucket'),
    ('05-credentials-to-bucket', 'editor_sa', 'lake',    true,  'roles/editor on acme-data, expanded from the projectEditor:acme-data legacy member'),
    ('05-credentials-to-bucket', 'shop_sa',   'exports', false, 'storage.objectCreator has no storage.objects.get'),
    ('05-credentials-to-bucket', 'analyst',   '*',       false, 'projectViewer:acme-data expands to a user, not a service account'),

    ('06-repo-push-builds', 'repo_web',    'trg_web',    true,  'the trigger watches pushes to main of acmeco/web'),
    ('06-repo-push-builds', 'repo_ops',    'trg_ops',    true,  'the trigger watches tags of acmeco/ops'),
    ('06-repo-push-builds', 'repo_docs',   '*',          false, 'no trigger watches acmeco/docs'),
    ('06-repo-push-builds', '*',           'trg_manual', false, 'a manual trigger watches no repo'),
    ('06-repo-push-builds', 'repo_legacy', 'trg_legacy', false, 'the trigger is disabled (falsifier: trigger deleted or disabled)'),

    ('08-build-holds-credentials', 'trg_web',    'build_sa', true,  'the trigger runs as build-sa'),
    ('08-build-holds-credentials', 'trg_ops',    'ci_sa',    true,  'the trigger runs as ci-sa'),
    ('08-build-holds-credentials', 'trg_manual', 'keys_sa',  true,  'the trigger runs as keys-sa'),
    ('08-build-holds-credentials', 'trg_web',    'web_sa',   false, 'the trigger deploys a service that runs as web-sa but does not run as it'),
    ('08-build-holds-credentials', 'trg_legacy', '*',        false, 'the trigger names no service account'),

    ('09-privesc-impersonation-1hop', 'keys_sa', 'ci_sa',        true,  'key admin on project acme-ops covers ci-sa'),
    ('09-privesc-impersonation-1hop', 'keys_sa', 'admin_sa',     true,  'key admin on project acme-ops covers admin-sa'),
    ('09-privesc-impersonation-1hop', 'keys_sa', 'auditor_sa',   true,  'key admin on project acme-ops covers auditor-sa'),
    ('09-privesc-impersonation-1hop', 'keys_sa', 'projadmin_sa', true,  'key admin on project acme-ops covers projadmin-sa'),
    ('09-privesc-impersonation-1hop', 'ci_sa',   'admin_sa',     true,  'actAs on admin-sa and cloudbuild.builds.create in acme-ops'),
    ('09-privesc-impersonation-1hop', 'keys_sa', 'keys_sa',      false, 'no self-edge'),
    ('09-privesc-impersonation-1hop', 'keys_sa', 'web_sa',       false, 'key admin on acme-ops does not reach SAs in acme-web'),
    ('09-privesc-impersonation-1hop', 'ci_sa',   'web_sa',       false, 'actAs on web-sa, but builds.create only in acme-ops, not acme-web'),
    ('09-privesc-impersonation-1hop', 'ci_sa',   'keys_sa',      false, 'builds.create in acme-ops, but no actAs on keys-sa'),
    ('09-privesc-impersonation-1hop', 'half_sa', '*',            false, 'actAs on shop-sa without cloudbuild.builds.create'),
    ('09-privesc-impersonation-1hop', 'editor_sa', '*',          false, 'roles/editor on acme-data reaches only itself; no self-edge'),

    ('14-credential-deploys-code', 'build_sa', 'web',  true,  'run.services.update on web and actAs on web-sa'),
    ('14-credential-deploys-code', 'half_sa',  '*',    false, 'update on web but actAs only on shop-sa, the runtime SA of another service'),
    ('14-credential-deploys-code', 'ci_sa',    '*',    false, 'actAs on web-sa without run.services.update'),

    ('20-base-image-poisoning', 'ci_sa',   'web',  true,  'upload on the base repo, whose python image is a diff_ids prefix of the serving web image'),
    ('20-base-image-poisoning', 'ci_sa',   'shop', false, 'the shop image has no collected base'),
    ('20-base-image-poisoning', 'keys_sa', '*',    false, 'upload on the tools repo, whose image is not a prefix of any serving image'),
    ('20-base-image-poisoning', 'half_sa', '*',    false, 'upload on the apps repo, which holds the serving image itself, not its base'),

    ('21-identity-administers-control-plane', 'admin_sa',     'org',    true,  'organizations.setIamPolicy on the org'),
    ('21-identity-administers-control-plane', 'admin_sa',     'folder', true,  'folders.setIamPolicy inherited from the org'),
    ('21-identity-administers-control-plane', 'admin_sa',     'p_web',  true,  'projects.setIamPolicy inherited from the org'),
    ('21-identity-administers-control-plane', 'projadmin_sa', 'p_web',  true,  'projects.setIamPolicy on acme-web'),
    ('21-identity-administers-control-plane', 'projadmin_sa', 'p_ops',  false, 'the binding is on acme-web only'),
    ('21-identity-administers-control-plane', 'projadmin_sa', 'folder', false, 'projects.setIamPolicy does not administer the parent folder'),
    ('21-identity-administers-control-plane', 'auditor_sa',   '*',      false, 'getIamPolicy on the org, no setIamPolicy')),
r AS (
    SELECT e.*, s.id AS src_id, d.id AS dst_id
    FROM e LEFT JOIN n s ON s.k = e.src LEFT JOIN n d ON d.k = e.dst)
SELECT 'expectation names an unknown node key' AS problem, rule || ': ' || src || ' > ' || dst AS detail
FROM r WHERE (src <> '*' AND src_id IS NULL) OR (dst <> '*' AND dst_id IS NULL)
UNION ALL
SELECT 'rule ' || rule || ' is missing an edge', src || ' > ' || dst || ': ' || why
FROM r WHERE want AND NOT EXISTS (
    SELECT 1 FROM abstract_edge a
    WHERE a.pack_id = 'gcp' AND a.rule = r.rule AND a.src = r.src_id AND a.dst = r.dst_id)
UNION ALL
SELECT 'rule ' || r.rule || ' emitted a forbidden edge', a.src || ' > ' || a.dst || ': ' || r.why
FROM r JOIN rule_edge a
  ON a.pack_id = 'gcp' AND a.rule = r.rule
 AND (r.src = '*' OR a.src = r.src_id) AND (r.dst = '*' OR a.dst = r.dst_id)
WHERE NOT r.want
UNION ALL
-- Rule 03 is static: exists is 0.4, and traverse is the highest EPSS among
-- the network/no-UI CVEs of the serving images, raised to 0.9 when one of
-- them is in KEV. web: 0.20 and 0.55, none in KEV, so 0.55. The local CVE
-- (EPSS 0.97, KEV), the user-interaction CVE (0.80, KEV), and the CVE of
-- the 0% revision (0.99, KEV) must not count. shop: 0.20 and 0.05 in KEV,
-- so 0.9.
SELECT 'rule 03 confidence is wrong', x.k || ': exists ' || a.exists_confidence || ', traverse '
       || a.traverse_confidence || ', want 0.4 and ' || x.traverse
FROM (VALUES ('web', 0.55), ('shop', 0.9)) x(k, traverse)
JOIN n ON n.k = x.k
JOIN abstract_edge a ON a.rule = '03-anon-exploits-public-run' AND a.dst = n.id
WHERE abs(a.exists_confidence - 0.4) > 1e-9 OR abs(a.traverse_confidence - x.traverse) > 1e-9
UNION ALL
SELECT 'rule 03 emitted more than one edge for a service', dst || ': ' || count(*)
FROM rule_edge WHERE rule = '03-anon-exploits-public-run' GROUP BY dst HAVING count(*) > 1
UNION ALL
-- Rule 06 names the people and teams who can push in its witness: alice
-- (write) and team eng (push), not bob (read) or team readers (pull).
SELECT 'rule 06 witness pushers are wrong', x.who || ' should ' || CASE WHEN x.push THEN '' ELSE 'not ' END || 'be a pusher'
FROM (VALUES ('https://github.com/alice', true), ('https://github.com/orgs/acmeco/teams/eng', true),
             ('https://github.com/bob', false), ('https://github.com/orgs/acmeco/teams/readers', false)) x(who, push)
JOIN n ON n.k = 'trg_web'
LEFT JOIN abstract_edge a ON a.rule = '06-repo-push-builds' AND a.dst = n.id
WHERE coalesce(list_contains(CAST(a.witness->'$.pushers' AS VARCHAR[]), x.who), false) <> x.push
UNION ALL
-- Rule 09 reports which path made each edge.
SELECT 'rule 09 witness lacks the path', x.src || ' > admin_sa via ' || x.via
FROM (VALUES ('keys_sa', 'iam.serviceAccountKeys.create'),
             ('ci_sa', 'iam.serviceAccounts.actAs + cloudbuild.builds.create')) x(src, via)
JOIN n s ON s.k = x.src JOIN n d ON d.k = 'admin_sa'
WHERE NOT EXISTS (
    SELECT 1 FROM abstract_edge a
    WHERE a.rule = '09-privesc-impersonation-1hop' AND a.src = s.id AND a.dst = d.id
      AND contains(a.witness::VARCHAR, x.via))
UNION ALL
-- A legacy projectEditor:<project> bucket member expands to the members
-- that hold roles/editor on that project.
SELECT 'projectEditor:acme-data does not expand to editor-sa', NULL
FROM n l JOIN n s ON l.k = 'lake' AND s.k = 'editor_sa'
WHERE NOT EXISTS (
    SELECT 1 FROM gcp_binding b
    WHERE b.resource_id = l.id AND b.member = 'projectEditor:acme-data' AND b.member_id = s.id)
UNION ALL
SELECT 'a rule emitted a self-edge', rule || ': ' || src FROM rule_edge WHERE src = dst
UNION ALL
SELECT 'edge rejected: ' || reason, rule || ': ' || src || ' > ' || dst FROM edge_reject
UNION ALL
SELECT 'record rejected by ingest', batch_id || ': ' || reason FROM reject
UNION ALL
-- Exposure alone: rule 01 grants reach, and nothing needs reach, so the
-- edge appears in no chain. blog is public with no exploitable CVE, so no
-- chain passes through it.
SELECT 'a chain uses the network_access edge', array_to_string(path, ' > ')
FROM chain WHERE list_contains(rules, 'gcp/01-internet-to-run')
UNION ALL
SELECT 'a chain passes through the unexploitable public service', array_to_string(c.path, ' > ')
FROM chain c JOIN n ON n.k = 'blog' WHERE list_contains(c.path, n.id)
UNION ALL
-- End-to-end chains to goals. A: exploit the public service, take its
-- token, read the bucket. B: push to the repo whose trigger deploys web.
-- C: poison web's base image from the ops CI. D: impersonate the org admin
-- from the ops CI.
SELECT x.name, 'no chain follows this path' FROM (
    SELECT name, list(n.id ORDER BY i) AS path
    FROM (SELECT name, unnest(keys) AS k, generate_subscripts(keys, 1) AS i FROM (VALUES
        ('chain A', ['internet', 'web', 'web_sa', 'exports', 'exports_c']),
        ('chain B', ['repo_web', 'trg_web', 'build_sa', 'web', 'web_sa', 'exports', 'exports_c']),
        ('chain C', ['repo_ops', 'trg_ops', 'ci_sa', 'web', 'web_sa', 'exports', 'exports_c']),
        ('chain D', ['repo_ops', 'trg_ops', 'ci_sa', 'admin_sa', 'org'])) v(name, keys)) h
    JOIN n USING (k) GROUP BY name) x
WHERE NOT EXISTS (SELECT 1 FROM chain c WHERE c.path = x.path)
UNION ALL
SELECT 'chain C', 'hop 3 is not from the base-image rule' FROM n
WHERE n.k = 'ci_sa' AND NOT EXISTS (
    SELECT 1 FROM chain c WHERE c.path[3] = n.id AND c.rules[3] = 'gcp/20-base-image-poisoning')
UNION ALL
SELECT 'goal value is wrong', x.k || ' want ' || x.value || ', got ' || coalesce(g.value::VARCHAR, 'no goal')
FROM (VALUES ('org', 100000), ('folder', 10000), ('p_web', 1000), ('exports_c', 15000)) x(k, value)
JOIN n USING (k) LEFT JOIN goal g ON g.node_id = n.id
WHERE g.value IS DISTINCT FROM x.value
