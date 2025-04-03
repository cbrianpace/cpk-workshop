\pset border 2
\pset linestyle unicode
\set ECHO queries

CREATE PUBLICATION hreast_pub
FOR TABLE emp, heartbeat;

SELECT * FROM pg_create_logical_replication_slot('hrwest', 'pgoutput');