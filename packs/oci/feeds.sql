-- Feeds from collectors/vuln.
--
-- oci-image holds one line per collected digest: manifest, config, and
-- lineage. Image content never changes, so it is an event feed.
--
-- The gcp-aa-* feeds are Artifact Analysis occurrences. Each batch is the
-- complete set for every digest it covers, so they are snapshots scoped by
-- digest. A digest counts as covered only when _meta.json marks it ok.
INSERT INTO feed_manifest
    (feed_id, pack_id, kind, format, record_path, identity, valid_from, scope, scopes, required, max_drop_pct, provenance)
VALUES
    ('oci-image', 'oci', 'event', 'ndjson', NULL,
     $$json->>'$.digest'$$,
     $$meta->>'$.started'$$,
     NULL, NULL,
     [$$json->>'$.platform_ref'$$],
     NULL, 'config'),
    ('gcp-aa-vulnerability', 'oci', 'snapshot', 'ndjson', NULL,
     $$json->>'$.name'$$,
     $$json->>'$.updateTime'$$,
     $$regexp_replace(json->>'$.resourceUri', '^https://', '')$$,
     $$list_filter(json_keys(meta->'$.statuses'), lambda k: json_extract_string(meta->'$.statuses', '$."' || k || '".status') = 'ok')$$,
     [$$json->>'$.resourceUri'$$, $$json->>'$.noteName'$$],
     NULL, 'static'),
    ('gcp-aa-build', 'oci', 'snapshot', 'ndjson', NULL,
     $$json->>'$.name'$$,
     $$json->>'$.updateTime'$$,
     $$regexp_replace(json->>'$.resourceUri', '^https://', '')$$,
     $$list_filter(json_keys(meta->'$.statuses'), lambda k: json_extract_string(meta->'$.statuses', '$."' || k || '".status') = 'ok')$$,
     [$$json->>'$.resourceUri'$$, $$json->>'$.noteName'$$],
     NULL, 'config'),
    ('gcp-aa-discovery', 'oci', 'snapshot', 'ndjson', NULL,
     $$json->>'$.name'$$,
     $$json->>'$.updateTime'$$,
     $$regexp_replace(json->>'$.resourceUri', '^https://', '')$$,
     $$list_filter(json_keys(meta->'$.statuses'), lambda k: json_extract_string(meta->'$.statuses', '$."' || k || '".status') = 'ok')$$,
     [$$json->>'$.resourceUri'$$],
     NULL, 'config'),
    ('gcp-aa-package', 'oci', 'snapshot', 'ndjson', NULL,
     $$json->>'$.name'$$,
     $$json->>'$.updateTime'$$,
     $$regexp_replace(json->>'$.resourceUri', '^https://', '')$$,
     $$list_filter(json_keys(meta->'$.statuses'), lambda k: json_extract_string(meta->'$.statuses', '$."' || k || '".status') = 'ok')$$,
     [$$json->>'$.resourceUri'$$, $$json->>'$.noteName'$$],
     NULL, 'static');
