-- A feed_id declared more than once, if any.
SELECT feed_id FROM feed_manifest GROUP BY feed_id HAVING count(*) > 1 LIMIT 1
