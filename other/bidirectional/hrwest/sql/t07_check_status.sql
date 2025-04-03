\pset border 2
\pset linestyle unicode
\set ECHO queries

SELECT slot_name, slot_type, database, active, confirmed_flush_lsn 
FROM pg_replication_slots;

SELECT oid, subname, subenabled 
FROM pg_subscription;

SELECT * 
FROM pg_stat_subscription_stats;
