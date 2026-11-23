-- Every current CAI resource except Docker images, which the oci pack owns,
-- plus one unexamined-contents node per container with a storage prior.
SELECT id, label FROM gcp_resource WHERE label <> 'artifactregistry.googleapis.com/DockerImage'
UNION ALL
SELECT r.id || '#contents', 'caizen/UnscannedContents'
FROM gcp_resource r JOIN storage_prior p ON p.label = r.label
