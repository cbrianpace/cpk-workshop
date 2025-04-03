\pset border 2
\pset linestyle unicode
\set ECHO queries

SET SESSION AUTHORIZATION repuser;

CREATE SUBSCRIPTION hreast_sub
      CONNECTION 'host=hreast-primary port=5432 user=repuser password=welcome1 dbname=postgres'
      PUBLICATION hreast_pub
WITH (origin = none, copy_data = true, create_slot = false, slot_name='hrwest', run_as_owner=true, disable_on_error=true);

SET SESSION AUTHORIZATION postgres;
