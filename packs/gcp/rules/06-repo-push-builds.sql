-- rule: 06-repo-push-builds
-- intent: whoever can push to a repo's branch or tag that a build trigger
--         watches runs code in that build. The chain starts at the repo;
--         the people and teams who can push are in the witness.
-- falsifiers: trigger deleted or disabled; trigger filter no longer matches
--             any ref that a pusher can create; a rule requires review
SELECT t.repo_id AS src, t.id AS dst, 'code' AS src_type, 'compute' AS dst_type,
       'supply_chain' AS etype, 'initial_access' AS phase, 'T1195' AS tech, '002' AS subtech,
       'Supply Chain Compromise: Compromise Software Supply Chain' AS title, 'config' AS provenance,
       json_object('event', t.event,
                   'pushers', (SELECT list(DISTINCT a.principal_id ORDER BY a.principal_id)
                               FROM github_repo_access a WHERE a.repo_id = t.repo_id AND a.push)) AS witness,
       'the trigger still builds pushes to this repo AND someone outside review can push a matching ref' AS truth_condition
FROM gcp_build_trigger t
WHERE t.repo_id IS NOT NULL
