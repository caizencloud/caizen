-- The roles GCP resources can play, which of them are goals, and the value
-- of the unexamined contents of each kind of container.
INSERT INTO node_type (pack_id, label, abstract_types) VALUES
    ('gcp', 'run.googleapis.com/Service',                    ['compute']),
    ('gcp', 'cloudbuild.googleapis.com/BuildTrigger',        ['compute']),
    ('gcp', 'iam.googleapis.com/ServiceAccount',             ['identity', 'credentials']),
    ('gcp', 'storage.googleapis.com/Bucket',                 ['storage']),
    ('gcp', 'artifactregistry.googleapis.com/Repository',    ['storage']),
    ('gcp', 'secretmanager.googleapis.com/Secret',           ['secret']),
    ('gcp', 'cloudresourcemanager.googleapis.com/Organization', ['control_plane']),
    ('gcp', 'cloudresourcemanager.googleapis.com/Folder',    ['control_plane']),
    ('gcp', 'cloudresourcemanager.googleapis.com/Project',   ['control_plane']);

INSERT INTO value_class (pack_id, label, class) VALUES
    ('gcp', 'cloudresourcemanager.googleapis.com/Organization', 'control_plane:org'),
    ('gcp', 'cloudresourcemanager.googleapis.com/Folder',       'control_plane:folder'),
    ('gcp', 'cloudresourcemanager.googleapis.com/Project',      'control_plane:project');

INSERT INTO storage_prior (pack_id, label, value) VALUES
    ('gcp', 'storage.googleapis.com/Bucket',              15000),
    ('gcp', 'artifactregistry.googleapis.com/Repository',   500);
