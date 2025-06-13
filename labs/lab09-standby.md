# Standby/DR Lab

## Objectives

- Create standby cluster
- Switchover to standby
- Switchback from standby

## Important note

This lab works with two different clusters.  The steps will indicate which cluster and manifest
the step should be performed against.  The two clusters will be referred to as **hippo/prod**
and **hippo/standby**.  This is a reference to the directory that stores the yaml files.

## Create standby cluster

### Delete current cluster

Delete the  current cluster to prepare environment.

```shell
kubectl delete -k hippo/prod
```

### Enable certificates:  hippo/prod

In order to replicate between two different clusters, the certificates used must be
signed by the same certificate authority (CA).

Edit the `hipp/prod/hippo-pg.yaml` file and uncomment the `customReplicationTLSSecret`
and `customTLSSecret` sections.

```text
customReplicationTLSSecret:
   name: hippo-repl-tls-custom
 customTLSSecret:
   name: hippo-tls-customspec: 
```

### Uncomment standby section:  hippo/prod

The `spec.standby` section controls the behavior and options for create a standby.

Edit the `hipp/prod/hippo-pg.yaml` file and uncomment the `spec.standby` section.

```text
  standby:
    enabled: false
    host: hippo-dr-primary
    port: 5432
```

### Deploy hippo/prod

Apply the updated manifest for `hippo/prod`.

```shell
kubectl apply -k hippo/prod
```

### View hippo/standby manifest

View the `hippo/standby/hippo-dr-pg.yaml` file and notice the certificate
sections and the standby section is already configured for you.

```text
  customReplicationTLSSecret:
    name: hippo-dr-repl-tls-custom
  customTLSSecret:
    name: hippo-dr-tls-custom
  
  standby:
    enabled: true
    host: hippo-primary
    port: 5432
```

### Create standby cluster hippo/standby

Create the standby cluster by apply the manifest.

```shell
kubectl apply -k hippo/standby
```

### Verify replication

As part of the initalization script, a `test` table was created.

On the `hippo/prod` cluster insert a row using the following.

```shell
export PGPASSWORD=$(kubectl get secret hippo-pguser-appuser --template={{.data.password}} | base64 --decode)

psql -U appuser -d postgres -h hippo-primary.postgres-operator -c "insert into test (chkdate) values (current_timestamp)"
```

Now connect to `hippo/standby` and verify a row exists in the `test` table.

```shell
psql -U appuser -d postgres -h hippo-dr-primary.postgres-operator -c "select * from test"
```

### Switchover

The switchover involves demoting the current primary and promoting the standby.  This can be done by modifying the manifest
to toggle `spec.standby.enabled` from false to true.  Then applying.  To promote, toggle the same setting from true to false.

In this lab, we are going to patch the manifest.

#### Demote hippo/prod

```shell
kubectl patch postgrescluster hippo --type merge --patch '{"spec":{"standby": {"enabled": true}}}'
```

Now, verify that the `hippo/prod` cluster has been demoted by checking `pg_is_in_recovery()`.  This should
return `t` for true when the demotion is successful.

```shell
psql -U appuser -d postgres -h hippo-primary.postgres-operator -c "select pg_is_in_recovery()"
```

#### Promote hippo/standby

```shell
kubectl patch postgrescluster hippo-dr --type merge --patch '{"spec":{"standby": {"enabled": false}}}'
```

Now, verify that the `hippo/standby` cluster has been promoted by checking `pg_is_in_recovery()`.  This should
return `t` for true when the demotion is successful.

```shell
psql -U appuser -d postgres -h hippo-dr-primary.postgres-operator -c "select pg_is_in_recovery()"
```

### Verify replication after switchover

On the `hippo/standby` cluster insert a row using the following.

```shell
psql -U appuser -d postgres -h hippo-dr-primary.postgres-operator -c "insert into test (chkdate) values (current_timestamp)"
```

Now connect to `hippo/prod` and verify a row exists in the `test` table.

```shell
psql -U appuser -d postgres -h hippo-dr-primary.postgres-operator -c "select * from test"
```

## Clean-up

To reset our cluster back for future labs, execute the following to clean-up the environment.

### Delete clusters

```shell
kubectl delete -k hippo/prod

kubectl delete -k hippo/standby
```

### Recreate `hippo/prod`

```shell
kubectl apply -k hippo/prod
```
