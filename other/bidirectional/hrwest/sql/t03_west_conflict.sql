\pset border 2
\pset linestyle unicode
\set ECHO queries

BEGIN;
UPDATE emp SET last_name='Jones' WHERE eid=1;
COMMIT;