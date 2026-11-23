-- Each edge on at least one chain, with the number of chains through it and
-- the sum of their scores: the confidence-weighted value it carries.
DELETE FROM choke;
INSERT INTO choke
SELECT path[i] AS src, path[i + 1] AS dst, etypes[i] AS etype, count(*), sum(score)
FROM chain, generate_series(1, len(etypes)) t(i)
GROUP BY ALL;
