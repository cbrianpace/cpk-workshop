\pset border 2
\pset linestyle unicode
\set ECHO queries

SELECT * FROM emp WHERE eid=5;
BEGIN;
UPDATE emp SET last_name='Smith', last_update=current_timestamp WHERE eid=5;
COMMIT;