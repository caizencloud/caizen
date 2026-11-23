-- Every declared feed, with required as a JSON array for Go to decode.
SELECT feed_id, kind, format, record_path, identity, valid_from, scope, scopes,
       to_json(required)::VARCHAR, max_drop_pct
FROM feed_manifest
