\pset border 2
\pset linestyle unicode
\set ECHO queries

SELECT * 
FROM  emp 
WHERE eid IN (1,3) 
ORDER BY eid;