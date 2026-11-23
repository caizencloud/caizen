-- rule: 16-storage-unscanned-contents
-- intent: a container whose label has a storage prior holds contents that
--         nobody has examined, worth the prior until a scan classifies them.
--         Every such container gets one contains edge to its #contents node.
-- falsifiers: a scan lists the container and finds it empty; a classifier
--             assigns the contents a class
SELECT c.id AS src, n.id AS dst, 'storage' AS src_type, 'data' AS dst_type,
       'contains' AS etype, 'collection' AS phase, 'T1530' AS tech, NULL AS subtech,
       'Data from Cloud Storage' AS title, 'config' AS provenance,
       json_object('container', c.id, 'label', c.label, 'examined', false) AS witness,
       'the container still exists AND no scan has classified its contents' AS truth_condition
FROM node c
JOIN storage_prior p ON p.label = c.label
JOIN node n ON n.id = c.id || '#contents' AND n.label = 'caizen/UnscannedContents'
