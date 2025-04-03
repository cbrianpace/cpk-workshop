\pset border 2
\pset linestyle unicode
\set ECHO queries

SELECT source_db, hb_date, rc_date-hb_date hb_lag, current_timestamp-hb_date tx_lag 
FROM   heartbeat 
WHERE  source_db != current_setting('cluster_name') 
ORDER BY 1;

SELECT source_db, hb_date, rc_date-hb_date hb_lag 
FROM   heartbeat_hist 
WHERE  source_db != current_setting('cluster_name') 
ORDER BY source_db, hb_date DESC 
LIMIT 10;