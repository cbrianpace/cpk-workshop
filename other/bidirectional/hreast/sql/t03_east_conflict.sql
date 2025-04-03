\pset border 2
\pset linestyle unicode
\set ECHO queries

BEGIN;
SELECT * FROM emp WHERE eid=1;
UPDATE emp SET email='bugs.bunny@acme.com' WHERE eid=1;