-- The closed model vocabulary that every pack shares (ADR-0020 §1).

-- Each edge type's capability contract (ADR-0007, taxonomy.md): what the
-- attacker must already hold, and what taking the edge grants. traverse is
-- the confidence that a config-derived edge of the type, once real, can be
-- taken. Cloud permission logic is deterministic, so it is close to 1.
INSERT INTO edge_type (pack_id, etype, requires, grants, traverse) VALUES
    ('core', 'network_access',    NULL,             'reach',          1.0),
    ('core', 'code_execution',    NULL,             'exec',           1.0),
    ('core', 'supply_chain',      NULL,             'exec',           1.0),
    ('core', 'valid_accounts',    NULL,             'exec',           1.0),
    ('core', 'use_credential',    'hold',           'exec',           0.98),
    ('core', 'credential_access', 'exec',           'hold',           0.995),
    ('core', 'reads_data',        'hold',           'storage_access', 0.99),
    ('core', 'contains',          'storage_access', NULL,             1.0),
    ('core', 'priv_esc',          'hold',           'control',        0.999);

-- The abstract types each edge type may join (ADR-0016).
INSERT INTO edge_endpoint (pack_id, etype, src_type, dst_type) VALUES
    ('core', 'network_access',    'internet',    'compute'),
    ('core', 'network_access',    'internet',    'storage'),
    ('core', 'code_execution',    'internet',    'compute'),
    ('core', 'code_execution',    'compute',     'compute'),
    ('core', 'supply_chain',      'code',        'compute'),
    ('core', 'supply_chain',      'code',        'code'),
    ('core', 'valid_accounts',    'internet',    'identity'),
    ('core', 'use_credential',    'credentials', 'compute'),
    ('core', 'credential_access', 'compute',     'credentials'),
    ('core', 'reads_data',        'credentials', 'storage'),
    ('core', 'contains',          'storage',     'data'),
    ('core', 'priv_esc',          'identity',    'identity'),
    ('core', 'priv_esc',          'identity',    'control_plane');

-- The value of each goal class. Provider packs map their labels to these
-- classes in value_class (ADR-0020 §4).
INSERT INTO class_value (pack_id, class, value) VALUES
    ('core', 'control_plane:org',     100000),
    ('core', 'control_plane:folder',   10000),
    ('core', 'control_plane:project',   1000),
    ('core', 'data:secrets',           95000),
    ('core', 'data:pii',               50000),
    ('core', 'data:other',               500);

-- Synthetic nodes. caizen/UnscannedContents stands for what is inside a
-- container that nobody has examined; each provider pack emits one per
-- container, and its value is the storage_prior of the container's label.
INSERT INTO node_type (pack_id, label, abstract_types) VALUES
    ('core', 'caizen/Internet',          ['internet']),
    ('core', 'caizen/UnscannedContents', ['data']);
