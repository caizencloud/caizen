-- rule: 20-base-image-poisoning
-- intent: a service account that can upload to the Artifact Registry repo
--         holding the base of a serving image can replace that base. The
--         next build of the image bakes the replacement in, and the service
--         then runs the attacker's code. One edge per service account and
--         service.
-- falsifiers: upload permission revoked; the image's build pins the base by
--             digest; the service stops serving an image built on that base
SELECT g.member_id AS src, i.service_id AS dst, 'credentials' AS src_type, 'compute' AS dst_type,
       'use_credential' AS etype, 'initial_access' AS phase, 'T1195' AS tech, '002' AS subtech,
       'Supply Chain Compromise: Compromise Software Supply Chain' AS title, 'config' AS provenance,
       json_object('bases', list(DISTINCT json_object('repository', gcp_image_repo(b.base_id), 'base', b.base_id,
                                                      'image', b.image_id, 'revision', i.revision_id)),
                   'upload', list(DISTINCT json_object('role', g.role, 'on', g.granted_on))) AS witness,
       'the service account can still upload to the base repository AND a serving image is still built on that base by tag' AS truth_condition
FROM gcp_run_image i
JOIN oci_base b ON b.image_id = i.image_id
JOIN gcp_grant g ON g.resource_id = gcp_image_repo(b.base_id)
                AND g.permission = 'artifactregistry.repositories.uploadArtifacts'
JOIN gcp_service_account sa ON sa.id = g.member_id
GROUP BY g.member_id, i.service_id
