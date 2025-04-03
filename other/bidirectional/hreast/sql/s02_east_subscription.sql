\pset border 2
\pset linestyle unicode
\set ECHO queries

SET SESSION AUTHORIZATION repuser;

CREATE SUBSCRIPTION hrwest_sub
  CONNECTION 'host=hrwest-primary port=5432 user=repuser password=welcome1 dbname=postgres'
  PUBLICATION hrwest_pub
  WITH (origin = none, copy_data = false, create_slot = false, slot_name='hreast', run_as_owner=true, disable_on_error=true);

SET SESSION AUTHORIZATION postgres;