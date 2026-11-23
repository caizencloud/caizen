-- The edges carrying the most confidence-weighted value. $1: how many.
SELECT src, dst, etype, chains, value FROM choke
ORDER BY value DESC, src, dst LIMIT $1
