--
-- Heartbeat Table
--

CREATE TABLE heartbeat (source_db varchar(10) not null primary key, hb_date timestamp, rc_date timestamp);

CREATE TABLE heartbeat_hist (source_db varchar(10) not null, hb_date timestamp, rc_date timestamp);

CREATE index heartbeat_hist_idx1 ON heartbeat_hist (source_db, hb_date);

CREATE OR REPLACE FUNCTION heartbeat_trg()
 RETURNS trigger
 LANGUAGE plpgsql
AS $$
DECLARE 
BEGIN
	
	IF old.source_db != current_setting('cluster_name') THEN 
		new.rc_date=current_timestamp;
        INSERT INTO public.heartbeat_hist (source_db, hb_date, rc_date) VALUES (old.source_db, new.hb_date, new.rc_date);
	END IF;

	RETURN NEW;
END;
$$
;

CREATE trigger heartbeat_trg BEFORE UPDATE ON heartbeat 
  FOR EACH ROW EXECUTE FUNCTION heartbeat_trg();

ALTER TABLE HEARTBEAT ENABLE ALWAYS TRIGGER heartbeat_trg ;

--
-- Employee Table
--

CREATE TABLE emp (eid int generated always as identity (start with 1 increment by 2) primary key,
                  first_name varchar(40),
                  last_name varchar(40),
                  email varchar(100),
                  hire_dt timestamp,
                  last_update timestamp default current_timestamp
                  );

--
-- Replication User
--

CREATE ROLE repuser WITH REPLICATION LOGIN PASSWORD 'welcome1';

GRANT all ON all tables IN schema public TO repuser;
GRANT all ON DATABASE postgres TO repuser;
GRANT pg_create_subscription TO repuser;
