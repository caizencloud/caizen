-- rule: 01-internet-to-run
-- intent: a Cloud Run service whose ingress is all and whose IAM lets
--         allUsers or allAuthenticatedUsers invoke it is reachable from the
--         internet. Reach only: the service still runs its own code.
-- falsifiers: invoker binding removed; ingress set to internal; the request
--             is refused by the app
SELECT 'caizen://internet' AS src, p.service_id AS dst, 'internet' AS src_type, 'compute' AS dst_type,
       'network_access' AS etype, 'discovery' AS phase, 'T1046' AS tech, NULL AS subtech,
       'Network Service Discovery' AS title, 'config' AS provenance,
       json_object('ingress', p.ingress, 'invokers', p.members) AS witness,
       'ingress is still all AND allUsers or allAuthenticatedUsers still holds run.routes.invoke' AS truth_condition
FROM gcp_run_public p
