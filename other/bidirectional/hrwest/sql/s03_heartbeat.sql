\pset border 2
\pset linestyle unicode
\set ECHO queries

INSERT INTO heartbeat (source_db, hb_date) VALUES (current_setting('cluster_name'), current_timestamp);
