-- The highest-scoring chains. $1: how many.
SELECT path, etypes, rules, confidence, value, score FROM chain
ORDER BY score DESC, path LIMIT $1
