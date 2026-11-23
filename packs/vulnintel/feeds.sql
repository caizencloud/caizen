-- Feeds from collectors/kev-epss.
--
-- cisa-kev is one JSON document; each element of vulnerabilities is a
-- record. first-epss is a gzip CSV whose first line is a #model_version
-- comment; its valid time is the date in the file name.
INSERT INTO feed_manifest
    (feed_id, pack_id, kind, format, record_path, identity, valid_from, scope, scopes, required, max_drop_pct, provenance)
VALUES
    ('cisa-kev', 'vulnintel', 'snapshot', 'json', '$.vulnerabilities[*]',
     $$json->>'$.cveID'$$,
     $$meta->>'$.date_released'$$,
     NULL, NULL, [],
     25, 'config'),
    ('first-epss', 'vulnintel', 'snapshot', 'csv', NULL,
     $$json->>'$.cve'$$,
     $$try_strptime(regexp_extract(obj.filename, 'epss_scores-(\d{4}-\d{2}-\d{2})', 1), '%Y-%m-%d')$$,
     NULL, NULL, [],
     25, 'config');
