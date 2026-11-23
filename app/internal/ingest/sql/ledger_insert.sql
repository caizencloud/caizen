-- $1 batch_id, $2 feed_id, $3 ingest_dt, $4 run, $5 status, $6 records,
-- $7 rejects, $8 reason.
INSERT INTO ledger
VALUES ($1, $2, CAST($3 AS DATE), CAST($4 AS TIMESTAMP), $5, $6, $7, $8, now()::TIMESTAMP)
