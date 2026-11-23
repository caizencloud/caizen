-- Where a fact comes from (ADR-0016): read from configuration, reported by
-- an agent, or found by a scanner.
CREATE TYPE provenance AS ENUM ('config', 'agent', 'static');

-- Feed declarations. Packs fill this table from their feeds.sql at every
-- start. Expressions are DuckDB SQL over the names json (one record), meta
-- (the batch _meta.json), and obj (the source object: obj.filename).
-- A snapshot feed keeps SCD history, an event feed appends, and a latest
-- feed keeps only its newest accepted batch.
CREATE TABLE feed_manifest (
    feed_id      VARCHAR NOT NULL,
    pack_id      VARCHAR NOT NULL,
    kind         VARCHAR NOT NULL CHECK (kind IN ('snapshot', 'event', 'latest')),
    format       VARCHAR NOT NULL CHECK (format IN ('ndjson', 'json', 'csv')),
    record_path  VARCHAR,                -- JSON path that unnests records; NULL means one record per line or row
    identity     VARCHAR NOT NULL,       -- expression for record_id
    valid_from   VARCHAR NOT NULL,       -- expression for the record's valid time
    scope        VARCHAR,                -- scoped snapshots: expression for the record's scope
    scopes       VARCHAR,                -- scoped snapshots: expression over meta for the scopes a batch covers
    required     VARCHAR[] NOT NULL DEFAULT [],  -- foreign-ID expressions; one NULL rejects the batch
    max_drop_pct DOUBLE,                 -- unscoped snapshots: quarantine below this drop
    provenance   provenance NOT NULL,
    CHECK ((scope IS NULL) = (scopes IS NULL)),
    CHECK (scope IS NULL OR kind = 'snapshot')
);

-- Per-feed loader state. manifest_hash is the hash of the feed's manifest
-- row when its records were loaded; a changed hash rebuilds the feed.
-- history_complete is true once a pass has listed the feed's whole history
-- and decided every batch in it; until then, discovery lists everything.
CREATE TABLE feed_state (
    feed_id          VARCHAR NOT NULL,
    manifest_hash    VARCHAR NOT NULL,
    history_complete BOOLEAN NOT NULL
);

-- One row per batch the loader has decided on.
CREATE TABLE ledger (
    batch_id  VARCHAR NOT NULL,          -- <feed>/ingest_dt=<date>/run=<time>
    feed_id   VARCHAR NOT NULL,
    ingest_dt DATE NOT NULL,
    run       TIMESTAMP NOT NULL,        -- batch time, UTC
    status    VARCHAR NOT NULL CHECK (status IN ('accepted', 'quarantined', 'rejected', 'superseded')),
    records   BIGINT NOT NULL,           -- distinct record IDs in the batch, valid or not; 0 if unreadable
    rejects   BIGINT NOT NULL,
    reason    VARCHAR,
    loaded_at TIMESTAMP NOT NULL
);

-- Every feed lands here. Snapshot feeds keep one row per record per change,
-- with valid_to set when the record changed or went absent. Event feeds
-- append rows that never close. Latest feeds hold only the rows of their
-- newest accepted batch, all open.
CREATE TABLE record (
    feed_id    VARCHAR NOT NULL,
    record_id  VARCHAR NOT NULL,
    valid_from TIMESTAMP NOT NULL,
    valid_to   TIMESTAMP,
    end_reason VARCHAR CHECK (end_reason IN ('changed', 'absent')),
    scope      VARCHAR,
    data       JSON NOT NULL,
    data_hash  VARCHAR NOT NULL,
    batch_id   VARCHAR NOT NULL          -- the batch that opened the row
);

-- Records the loader refused, with the reason.
CREATE TABLE reject (
    batch_id VARCHAR NOT NULL,
    feed_id  VARCHAR NOT NULL,
    line     VARCHAR,
    reason   VARCHAR NOT NULL
);

-- Quarantined batches released by hand with caizen ingest -accept.
CREATE TABLE batch_accept (
    batch_id VARCHAR NOT NULL
);
