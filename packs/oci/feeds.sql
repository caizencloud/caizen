-- Feeds from collectors/vuln.
--
-- oci-image holds one line per collected digest: manifest, config, and
-- lineage. Image content never changes, so it is an event feed.
--
-- The gcp-aa-* feeds are Artifact Analysis occurrences. Each batch is the
-- complete set for every digest it covers, so they are snapshots scoped by
-- image. A scope is the image's resourceUri, https://<registry>/<path>@sha256:<hex>,
-- which is also the image's node ID. An image counts as covered only when
-- _meta.json marks it ok; _meta.json keys images without the scheme.
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
     $$json->>'$.resourceUri'$$,
     $$list_transform(list_filter(json_keys(meta->'$.statuses'), lambda k: json_extract_string(meta->'$.statuses', '$."' || k || '".status') = 'ok'), lambda k: 'https://' || k)$$,
     [$$json->>'$.resourceUri'$$, $$json->>'$.noteName'$$],
     NULL, 'static'),
    ('gcp-aa-build', 'oci', 'snapshot', 'ndjson', NULL,
     $$json->>'$.name'$$,
     $$json->>'$.updateTime'$$,
     $$json->>'$.resourceUri'$$,
     $$list_transform(list_filter(json_keys(meta->'$.statuses'), lambda k: json_extract_string(meta->'$.statuses', '$."' || k || '".status') = 'ok'), lambda k: 'https://' || k)$$,
     [$$json->>'$.resourceUri'$$, $$json->>'$.noteName'$$],
     NULL, 'config'),
    ('gcp-aa-discovery', 'oci', 'snapshot', 'ndjson', NULL,
     $$json->>'$.name'$$,
     $$json->>'$.updateTime'$$,
     $$json->>'$.resourceUri'$$,
     $$list_transform(list_filter(json_keys(meta->'$.statuses'), lambda k: json_extract_string(meta->'$.statuses', '$."' || k || '".status') = 'ok'), lambda k: 'https://' || k)$$,
     [$$json->>'$.resourceUri'$$],
     NULL, 'config'),
    ('gcp-aa-package', 'oci', 'snapshot', 'ndjson', NULL,
     $$json->>'$.name'$$,
     $$json->>'$.updateTime'$$,
     $$json->>'$.resourceUri'$$,
     $$list_transform(list_filter(json_keys(meta->'$.statuses'), lambda k: json_extract_string(meta->'$.statuses', '$."' || k || '".status') = 'ok'), lambda k: 'https://' || k)$$,
     [$$json->>'$.resourceUri'$$, $$json->>'$.noteName'$$],
     NULL, 'static');
