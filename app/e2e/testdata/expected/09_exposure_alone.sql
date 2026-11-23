-- The internet can reach the api (rule 01), but reach alone confers nothing
-- (ADR-0007): the edge exists, and no chain uses it.
SELECT 'rule 01 emitted no edge to the api' AS problem, NULL AS detail
WHERE NOT EXISTS (SELECT 1 FROM abstract_edge WHERE rule = '01-internet-to-run'
                  AND dst = 'https://run.googleapis.com/projects/ln-prod-web/locations/us-central1/services/api')
UNION ALL
SELECT 'a chain uses the network_access edge', array_to_string(path, ' > ')
FROM chain WHERE list_contains(rules, 'gcp/01-internet-to-run')
