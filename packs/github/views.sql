-- Every captured API response page.
CREATE VIEW github_page AS
SELECT data->>'$.endpoint' AS endpoint,
       TRY_CAST(data->>'$.page' AS INTEGER) AS page,
       TRY_CAST(data->>'$.status' AS INTEGER) AS status,
       data->'$.body' AS body
FROM record WHERE feed_id = 'github-api' AND valid_to IS NULL;

-- The elements of every successful page whose body is a list.
CREATE VIEW github_item AS
SELECT endpoint, unnest(CAST(body AS JSON[])) AS item
FROM github_page WHERE status = 200 AND json_type(body) = 'ARRAY';

CREATE VIEW github_repo AS
SELECT DISTINCT item->>'$.html_url' AS id, item->>'$.full_name' AS full_name
FROM github_item WHERE regexp_matches(endpoint, '^/orgs/[^/]+/repos');

-- Who can write to each repo, directly or through a team. push is true for
-- the write, maintain, and admin roles.
CREATE VIEW github_repo_access AS
SELECT 'https://github.com/' || regexp_extract(endpoint, '^/repos/([^/]+/[^/]+)/', 1) AS repo_id,
       item->>'$.html_url' AS principal_id, 'user' AS kind,
       item->>'$.role_name' AS permission,
       coalesce(TRY_CAST(item->>'$.permissions.push' AS BOOLEAN), false) AS push
FROM github_item WHERE regexp_matches(endpoint, '^/repos/[^/]+/[^/]+/collaborators')
UNION ALL
SELECT 'https://github.com/' || regexp_extract(endpoint, '^/repos/([^/]+/[^/]+)/', 1),
       item->>'$.html_url', 'team', item->>'$.permission',
       item->>'$.permission' IN ('push', 'maintain', 'admin')
FROM github_item WHERE regexp_matches(endpoint, '^/repos/[^/]+/[^/]+/teams');
