\pset border 2
\pset linestyle unicode
\set ECHO queries

DROP TRIGGER IF EXISTS emp_conflict_trg ON emp;

CREATE OR REPLACE FUNCTION emp_conflict_func() RETURNS trigger
   LANGUAGE plpgsql AS
$$
BEGIN

   IF NEW.last_update < OLD.last_update THEN
      RAISE EXCEPTION 'Conflict Detected: New record (%) is older than current record  (%) for eid %', NEW.last_update, OLD.last_update, NEW.eid;
   END IF;

   RETURN NEW;
END;
$$;

CREATE TRIGGER emp_conflict_trg
   BEFORE UPDATE ON emp FOR EACH ROW
   WHEN (current_user = 'repuser')
   EXECUTE PROCEDURE emp_conflict_func();

ALTER TABLE emp ENABLE ALWAYS TRIGGER emp_conflict_trg;