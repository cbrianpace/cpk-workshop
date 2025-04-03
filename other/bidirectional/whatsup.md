# Bidirection Replication Workshop

## Setup

### Namespace

```shell
kubectl create namespace crunchy
```

```shell
kubectl ns crunchy
```

### Deploy Clusters

```shell
kubectl apply -k hreast
```

```shell
kubectl apply -k hrwest
```

### Open Postgres Session to each cluster

```shell
kubectl exec -it $(kubectl get pod -l postgres-operator.crunchydata.com/role=master,postgres-operator.crunchydata.com/cluster=hreast -o name) -c database -- bash

psql
```

```shell
kubectl exec -it $(kubectl get pod -l postgres-operator.crunchydata.com/role=master,postgres-operator.crunchydata.com/cluster=hrwest -o name) -c database -- bash

psql
```

### Create Publications

#### HR-East Publication

```sql
\i /etc/postgres/s01_east_publication.sql
```

#### HR-West Publication

```sql
\i /etc/postgres/s01_west_publication.sql
```

### Create Subscriptions

#### HR-East Subscription

```sql
\i /etc/postgres/s02_east_subscription.sql
```

#### HR-West Subscription

```sql
\i /etc/postgres/s02_west_subscription.sql
```

### Populate Heartbeat Table

Run in both HREast and HRWest.

```sql
\i /etc/postgres/s03_heartbeat.sql
```

## Replication in Action

### Heartbeat

#### Start Heartbeat

```shell
./heartbeat.sh
```

#### Monitor Heartbeat

```sql
\i /etc/postgres/s04_monitor_heartbeat.sql
```

```sql
SELECT source_db, hb_date, rc_date-hb_date hb_lag, current_timestamp-hb_date tx_lag 
FROM   heartbeat 
WHERE  source_db != current_database() 
ORDER BY 1;
```

```sql
SELECT source_db, hb_date, rc_date-hb_date hb_lag 
FROM   heartbeat_hist 
WHERE  source_db != current_database() 
ORDER BY source_db, hb_date DESC 
LIMIT 10;
```

### Test Replication

#### HR-East Update 1

```sql
\i /etc/postgres/t01_select.sql
```

```sql
\i /etc/postgres/t02_east_update.sql
```

```sql
\i /etc/postgres/t01_select.sql
```

#### HR-West Update 1

```sql
\i /etc/postgres/t01_select.sql
```

```sql
\i /etc/postgres/t02_west_update.sql
```

```sql
\i /etc/postgres/t01_select.sql
```

### Latency

#### HR-West Latency

```sql
SELECT source_db, hb_date, rc_date-hb_date hb_lag 
FROM   heartbeat_hist 
WHERE  source_db != current_database() 
ORDER BY source_db, hb_date DESC
LIMIT 10;

\watch 5
```

#### HR-East Latency

```sql
INSERT INTO emp (first_name, last_name, email, hire_dt)
(SELECT 'test_'|| n as first_name, 
        'other_'|| n as last_name,
        'test_'|| n || '.other_' || n || '@example.com' as email,
        current_timestamp - (n || ' minute')::interval as hire_dt 
 FROM generate_series(1, 800000) as n);
```

### Monitoring

In addition to the heartbeat table, the following scripts are useful for monitoring logical replication.

```sql
SELECT pid, usename, application_name, backend_start, backend_xmin, 
       state, sent_lsn, write_lsn, flush_lsn, replay_lsn, 
       write_lag, flush_lag, replay_lag 
FROM   pg_stat_replication;
```

```sql
SELECT * 
FROM  pg_stat_replication_slots;
```

```sql
SELECT * 
FROM   pg_stat_subscription;
```

```sql
SELECT *
FROM   pg_stat_subscription_stats;
```

### Conflict

Now to deal with conflict.  With two sessions open to each database, the following steps will be performed to create conflict.  Do not commit in either session until instructed to do so.

#### HR-East Conflict Update

```sql
\i /etc/postgres/t03_east_conflict.sql
```

##### HR-West Conflict Update

```sql
\i /etc/postgres/t03_west_conflict.sql
```

The expectation after committing is that last_name will be equal to Jones and email will be bugs.bunny@acme.com.

Commit the transaction in pg1 and then in pg2. What happens?

##### HR-East Commit

```sql
COMMIT;
```

##### HR-East Check Data

```sql
SELECT * FROM emp WHERE eid=1;
```

##### HR-West Check Data

```sql
SELECT * FROM emp WHERE eid=1;
```

Now both rows are out of sync. In hreast, the update of the email was lost and in hrwest the update of last_name was lost.  This happens because the entire row is sent over during logical replication and not just the fields that were updated. In such cases, even eventual consistency is not possible.

### Conflict Resolution

In this example, a trigger is deployed to verify if the replicated record is newer or older than the current record.  If the record is older, then the change is rejected and subscription/apply process stopped.

First, let's deploy the trigger and modify the subscription.  The trigger is setup to raise an exception if the replicated record is older (based on last_update) than the current record.  If we just wanted to ignore the 'older' record, we could do 'RETURN NULL' instead of raising the exception.

#### Conflict Trigger

Deploy trigger to both HREast and HRWest.

```sql
\i /etc/postgres/t05_trigger.sql
```

##### HR-East Conflict 2

On hreast, start a transaction and update last_name to 'Jordan'.  **Do not commit**.  

This will create an update with an older last_update value.

```sql
\i /etc/postgres/t06_east_conflict2.sql
```

##### HR-West Conflict 2

On hrwest, the last_name is changed to 'Smith'.  This transaction is committed.

```sql
\i /etc/postgres/t06_west_conflict2.sql
```

##### HR-East Commit Conflict 2

```sql
COMMIT;
```

##### Review Replication State

At this point both hreast and hrwest should have a last_name of 'Smith' for eid 5.  

Also, the later committed update of the last_name to 'Jordan' should have been rejected and the subscription disabled.  

The replication slot will also show active equal to false.  To verify, execute the following:

```sql
\x
\i /etc/postgres/t07_check_status.sql
```

```sql
SELECT slot_name, slot_type, database, active, confirmed_flush_lsn 
FROM pg_replication_slots;
```

```sql
SELECT oid, subname, subenabled 
FROM pg_subscription;
```

```sql
SELECT * 
FROM pg_stat_subscription_stats;
```

##### Resolve Conflict

Looking into the Postgres log, a message similiar to the following will appear:

'''text
2023-10-24 20:22:52 UTC [14254]: [2-1] user=,db=,app=,client=ERROR:  Conflict Detected: New record (2023-10-24 20:13:58.111788) is older than current record  (2023-10-24 20:14:07.293333) for eid 5
2023-10-24 20:22:52 UTC [14254]: [3-1] user=,db=,app=,client=CONTEXT:  PL/pgSQL function public.emp_conflict_func() line 9 at RAISE
	processing remote data for replication origin "pg_16628" during message type "UPDATE" for replication target relation "public.emp" in transaction 13162, finished at 0/4F039BB0
2023-10-24 20:22:52 UTC [14254]: [4-1] user=,db=,app=,client=LOG:  subscription "hrsub2" has been disabled because of an error
'''

The trigger has rejected the updated record coming from pg1 as the last_update value is less than what currently exists in the table.  To get the subscription back going, skip the transaction by using the LSN in from the error in the Postgres log.

```sql
ALTER SUBSCRIPTION hr_sub SKIP (lsn='0/4F039BB0');
ALTER SUBSCRIPTION hr_sub ENABLE;
```
