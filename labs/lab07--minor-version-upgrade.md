# Postgres Minor Version Upgrade Lab

## Objectives

- Perform Postgres minor version upgrade

## Minor version Upgrade

### Check the current Postgres version

Use the following psql command to check the current version of Postgres.

```shell
export PGPASSWORD=$(kubectl get secret hippo-pguser-appuser --template={{.data.password}} | base64 --decode)

psql -U appuser -h hippo-primary.postgres-operator -c "select version()" -d appdev
```

### Perform upgrade

To perform upgrades of minor versions and/or monthly build versions, edit the `hippo/prod/hippo-pg.yaml` file
and switch the image tag to the next minor versions available.  The next available Postgres image is currently commented
out, comment out the current `spec.image` and uncomment the newer minor version.

Next, switch to the next version of pgBackrest.  To do this, comment out the current `spec.backups.pgbackrest.image` and 
uncomment out the newer version.

```text
spec:
   image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres:ubi9-16.9-2520
...
 backups:
    pgbackrest:
      image: registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest:ubi9-2.54.2-2520 
```

With the images changed, apply the updated manifest.

```shell
kubectl apply -k hippo/prod
```

Observer how the replicas are taken out of the cluster, upgraded, and then put back into the cluster.
Once all replicas are upgraded, a leader election takes place and the previous leader is then upgraded.

Verify the new Postgres version.

```shell
psql -U appuser -h hippo-primary.postgres-operator -c "select version()"
```
