-- Feed from collectors/repos. Each record is one API response page, valid
-- from the run's start. Views in this pack unnest the bodies and route them
-- by endpoint.
INSERT INTO feed_manifest
    (feed_id, pack_id, kind, format, record_path, identity, valid_from, scope, scopes, required, max_drop_pct, provenance)
VALUES
    ('github-api', 'github', 'snapshot', 'ndjson', NULL,
     $$(json->>'$.endpoint') || '#page=' || (json->>'$.page')$$,
     $$meta->>'$.started'$$,
     NULL, NULL,
     [$$json->>'$.status'$$],
     25, 'config');
