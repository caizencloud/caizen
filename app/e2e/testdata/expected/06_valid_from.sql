-- Valid times come from the declared sources: the KEV catalog's
-- dateReleased, the date in the EPSS file name, the GitHub run's start
-- (2026-11-23T18:07:00Z in _meta.json), and each CAI record's update_time at microsecond precision.
SELECT 'cisa-kev' AS feed_id, valid_from FROM record
WHERE feed_id = 'cisa-kev' AND valid_from <> TIMESTAMP '2026-11-18 19:17:41.0354'
UNION ALL
SELECT 'first-epss', valid_from FROM record
WHERE feed_id = 'first-epss' AND valid_from <> TIMESTAMP '2026-11-19 00:00:00'
UNION ALL
SELECT 'github-api', valid_from FROM record
WHERE feed_id = 'github-api' AND valid_from <> TIMESTAMP '2026-11-23 18:07:00'
UNION ALL
SELECT feed_id, valid_from FROM record
WHERE feed_id LIKE 'gcp-cai-%'
  -- update_time as text, its fraction cut or padded to microseconds.
  AND strftime(valid_from, '%Y-%m-%dT%H:%M:%S.%f') IS DISTINCT FROM
      left(data->>'$.update_time', 19) || '.' ||
      left(rpad(regexp_extract(data->>'$.update_time', '\.(\d+)Z$', 1), 6, '0'), 6)
