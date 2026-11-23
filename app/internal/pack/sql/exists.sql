-- $1: path.
SELECT count(*) FROM glob($1)
