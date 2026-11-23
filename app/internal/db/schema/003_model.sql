-- The attack-path model. The closed vocabulary is ENUM types, so a value
-- outside it fails on insert. A new value is a schema change.

-- What an attacker holds after taking an edge (ADR-0007).
CREATE TYPE capability AS ENUM ('reach', 'exec', 'hold', 'storage_access', 'control');

-- The roles a node can play (ADR-0021).
CREATE TYPE abstract_type AS ENUM (
    'internet', 'compute', 'code', 'identity', 'credentials', 'secret',
    'control_plane', 'storage', 'data');

-- Tables that packs fill. Each row carries the pack that inserted it, and
-- the pack loader replaces all of them on every load.

-- Edge types and their capability contract. traverse is the confidence
-- that a config-derived edge of this type, once real, can be taken.
CREATE TABLE edge_type (
    pack_id  VARCHAR NOT NULL,
    etype    VARCHAR NOT NULL,
    requires capability,                 -- NULL: traversal can start here
    grants   capability,                 -- NULL: a dead end, such as contains
    traverse DOUBLE NOT NULL CHECK (traverse > 0 AND traverse <= 1)
);

-- The legal (src_type, dst_type) pairs of each edge type (ADR-0016).
CREATE TABLE edge_endpoint (
    pack_id  VARCHAR NOT NULL,
    etype    VARCHAR NOT NULL,
    src_type abstract_type NOT NULL,
    dst_type abstract_type NOT NULL
);

-- The value of a class of goal. Packs map labels to classes; the core pack
-- alone sets the numbers (ADR-0020 §4).
CREATE TABLE class_value (
    pack_id VARCHAR NOT NULL,
    class   VARCHAR NOT NULL,
    value   BIGINT NOT NULL CHECK (value > 0)
);

-- The roles a node of each label can play.
CREATE TABLE node_type (
    pack_id        VARCHAR NOT NULL,
    label          VARCHAR NOT NULL,
    abstract_types abstract_type[] NOT NULL
);

-- The goal class of each label that is worth reaching.
CREATE TABLE value_class (
    pack_id VARCHAR NOT NULL,
    label   VARCHAR NOT NULL,
    class   VARCHAR NOT NULL
);

-- The value of the unexamined contents of a container of each label.
CREATE TABLE storage_prior (
    pack_id VARCHAR NOT NULL,
    label   VARCHAR NOT NULL,
    value   BIGINT NOT NULL CHECK (value > 0)
);

-- Each pack's nodes.sql and rules/*.sql, run on every model rebuild.
CREATE TABLE pack_query (
    pack_id VARCHAR NOT NULL,
    kind    VARCHAR NOT NULL CHECK (kind IN ('nodes', 'rule')),
    name    VARCHAR NOT NULL,            -- 'nodes', or the rule file name without .sql
    sql     VARCHAR NOT NULL
);

-- Tables the model rebuild replaces.

-- Every node the packs' nodes.sql queries emit.
CREATE TABLE node (
    id             VARCHAR NOT NULL,     -- an absolute URI
    label          VARCHAR NOT NULL,     -- <authority>/<Kind>
    abstract_types abstract_type[],      -- NULL when no node_type row covers the label
    pack_id        VARCHAR NOT NULL
);

-- Every edge the rules emit, before the coherence checks.
CREATE TABLE rule_edge (
    pack_id         VARCHAR NOT NULL,
    rule            VARCHAR NOT NULL,
    src             VARCHAR NOT NULL,
    dst             VARCHAR NOT NULL,
    src_type        abstract_type NOT NULL,
    dst_type        abstract_type NOT NULL,
    etype           VARCHAR NOT NULL,
    phase           VARCHAR NOT NULL,
    tech            VARCHAR,
    subtech         VARCHAR,
    title           VARCHAR,
    provenance      provenance NOT NULL,
    basis           JSON,                -- inputs the engine turns into confidence
    witness         JSON NOT NULL,       -- the concrete facts behind the edge
    truth_condition VARCHAR NOT NULL
);

-- Rule edges that failed a coherence check, and why. They are not scored.
CREATE TABLE edge_reject (
    pack_id VARCHAR NOT NULL,
    rule    VARCHAR NOT NULL,
    src     VARCHAR NOT NULL,
    dst     VARCHAR NOT NULL,
    etype   VARCHAR NOT NULL,
    reason  VARCHAR NOT NULL
);

-- Rule edges that passed every check, with the confidences the engine set.
CREATE TABLE abstract_edge (
    pack_id             VARCHAR NOT NULL,
    rule                VARCHAR NOT NULL,
    src                 VARCHAR NOT NULL,
    dst                 VARCHAR NOT NULL,
    src_type            abstract_type NOT NULL,
    dst_type            abstract_type NOT NULL,
    etype               VARCHAR NOT NULL,
    phase               VARCHAR NOT NULL,
    tech                VARCHAR,
    subtech             VARCHAR,
    title               VARCHAR,
    provenance          provenance NOT NULL,
    witness             JSON NOT NULL,
    truth_condition     VARCHAR NOT NULL,
    exists_confidence   DOUBLE NOT NULL,
    traverse_confidence DOUBLE NOT NULL
);

-- Nodes worth reaching, with their value.
CREATE TABLE goal (
    node_id VARCHAR NOT NULL,
    value   BIGINT NOT NULL
);

-- Tables the scorer replaces.

-- Every capability-gated walk that ends at a goal.
CREATE TABLE chain (
    path       VARCHAR[] NOT NULL,       -- node IDs from the first source to the goal
    etypes     VARCHAR[] NOT NULL,       -- the edge type of each hop
    rules      VARCHAR[] NOT NULL,       -- the pack/rule of each hop
    confidence DOUBLE NOT NULL,          -- product of exists x traverse over the hops
    value      BIGINT NOT NULL,          -- the goal's value
    score      DOUBLE NOT NULL           -- confidence x value
);

-- Each edge on at least one chain, with the confidence-weighted value that
-- flows through it (ADR-0006).
CREATE TABLE choke (
    src    VARCHAR NOT NULL,
    dst    VARCHAR NOT NULL,
    etype  VARCHAR NOT NULL,
    chains BIGINT NOT NULL,
    value  DOUBLE NOT NULL               -- sum of the scores of the chains through it
);
