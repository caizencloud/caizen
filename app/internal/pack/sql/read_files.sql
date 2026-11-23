-- Files matching a pattern, with their contents. $1: glob pattern.
SELECT filename, content FROM read_text($1) ORDER BY filename
