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
