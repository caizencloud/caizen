-- Cloud Asset Inventory exports from collectors/cai-export. One snapshot
-- feed per content type. update_time is when the asset last changed; the
-- export's read_time is the fallback.
INSERT INTO feed_manifest
    (feed_id, pack_id, kind, format, record_path, identity, valid_from, scope, scopes, required, max_drop_pct, provenance)
VALUES
    ('gcp-cai-resource', 'gcp', 'snapshot', 'ndjson', NULL,
     $$json->>'$.name'$$,
     $$COALESCE(json->>'$.update_time', meta->>'$.read_time')$$,
     NULL, NULL,
     [$$json->>'$.asset_type'$$, $$json->>'$.ancestors'$$],
     25, 'config'),
    ('gcp-cai-iam-policy', 'gcp', 'snapshot', 'ndjson', NULL,
     $$json->>'$.name'$$,
     $$COALESCE(json->>'$.update_time', meta->>'$.read_time')$$,
     NULL, NULL,
     [$$json->>'$.asset_type'$$, $$json->>'$.ancestors'$$],
     25, 'config'),
    ('gcp-cai-org-policy', 'gcp', 'snapshot', 'ndjson', NULL,
     $$json->>'$.name'$$,
     $$COALESCE(json->>'$.update_time', meta->>'$.read_time')$$,
     NULL, NULL,
     [$$json->>'$.asset_type'$$, $$json->>'$.ancestors'$$],
     25, 'config');

-- Predefined and basic IAM roles from collectors/iam-roles, one role per
-- line with its includedPermissions. Rules match permissions, never role
-- names, so every binding needs its role's permission list. The valid time
-- is the source commit's time. Some predefined roles have no permissions
-- and no includedPermissions key. Custom roles come from gcp-cai-resource as
-- iam.googleapis.com/Role.
INSERT INTO feed_manifest
    (feed_id, pack_id, kind, format, record_path, identity, valid_from, scope, scopes, required, max_drop_pct, provenance)
VALUES
    ('gcp-iam-role', 'gcp', 'snapshot', 'ndjson', NULL,
     $$json->>'$.name'$$,
     $$meta->>'$.committed_at'$$,
     NULL, NULL,
     [],
     25, 'config');
