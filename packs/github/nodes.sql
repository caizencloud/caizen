SELECT id, 'github.com/Repository' AS label FROM github_repo
UNION
SELECT item->>'$.html_url', 'github.com/User'
FROM github_item WHERE regexp_matches(endpoint, '^/orgs/[^/]+/(members|outside_collaborators)')
                    OR regexp_matches(endpoint, '^/repos/[^/]+/[^/]+/collaborators')
UNION
SELECT item->>'$.html_url', 'github.com/Team'
FROM github_item WHERE regexp_matches(endpoint, '^/orgs/[^/]+/teams(\?|$)')
