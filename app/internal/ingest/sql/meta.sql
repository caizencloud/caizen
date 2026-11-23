-- The batch's _meta.json. $1: path. Zero rows means the file is missing.
CREATE OR REPLACE TEMP TABLE _meta AS
SELECT content::JSON AS meta FROM read_text($1)
