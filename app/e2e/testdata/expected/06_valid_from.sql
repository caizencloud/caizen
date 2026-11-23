-- Valid times come from the declared sources: the KEV catalog's
-- dateReleased, the date in the EPSS file name, the GitHub run's start
-- (2026-11-23T20:23:51Z in _meta.json), the role source commit's time
-- (2026-11-15T07:31:41Z), and each CAI record's update_time at microsecond
-- precision.
SELECT 'cisa-kev' AS feed_id, valid_from FROM record
WHERE feed_id = 'cisa-kev' AND valid_from <> TIMESTAMP '2026-11-18 19:17:41.0354'
UNION ALL
SELECT 'first-epss', valid_from FROM record
WHERE feed_id = 'first-epss' AND valid_from <> TIMESTAMP '2026-11-19 00:00:00'
UNION ALL
SELECT 'github-api', valid_from FROM record
WHERE feed_id = 'github-api' AND valid_from <> TIMESTAMP '2026-11-23 20:23:51'
UNION ALL
SELECT 'gcp-iam-role', valid_from FROM record
WHERE feed_id = 'gcp-iam-role' AND valid_from <> TIMESTAMP '2026-11-15 07:31:41'
UNION ALL
SELECT feed_id, valid_from FROM record
WHERE feed_id LIKE 'gcp-cai-%'
  -- update_time as text, its fraction cut or padded to microseconds.
  AND strftime(valid_from, '%Y-%m-%dT%H:%M:%S.%f') IS DISTINCT FROM
      left(data->>'$.update_time', 19) || '.' ||
      left(rpad(regexp_extract(data->>'$.update_time', '\.(\d+)Z$', 1), 6, '0'), 6)
