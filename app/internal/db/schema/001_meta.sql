-- Key-value facts about the database file itself, such as schema_version.
CREATE TABLE caizen_meta (
    key   VARCHAR PRIMARY KEY,
    value VARCHAR NOT NULL
);
