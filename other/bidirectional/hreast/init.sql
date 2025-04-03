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

INSERT INTO emp (FIRST_NAME,LAST_NAME,EMAIL,HIRE_DT) VALUES ('John', 'Doe', 'johndoe@example.com', '2021-01-15 09:00:00'),
('Jane', 'Smith', 'janesmith@example.com', '2022-03-20 14:30:00'),
('Michael', 'Johnson', 'michaelj@example.com', '2020-12-10 10:15:00'),
('Emily', 'Williams', 'emilyw@example.com', '2023-05-05 08:45:00'),
('David', 'Brown', 'davidbrown@example.com', '2019-11-25 11:20:00'),
('Sarah', 'Taylor', 'saraht@example.com', '2022-09-08 13:00:00'),
('Robert', 'Anderson', 'roberta@example.com', '2021-07-12 16:10:00'),
('Jennifer', 'Martinez', 'jenniferm@example.com', '2023-02-18 09:30:00'),
('William', 'Jones', 'williamj@example.com', '2020-04-30 12:45:00'),
('Linda', 'Garcia', 'lindag@example.com', '2018-06-03 15:55:00');

--
-- Replication User
--

CREATE ROLE repuser WITH REPLICATION LOGIN PASSWORD 'welcome1';

GRANT all ON all tables IN schema public TO repuser;
GRANT all ON DATABASE postgres TO repuser;
GRANT pg_create_subscription TO repuser;
