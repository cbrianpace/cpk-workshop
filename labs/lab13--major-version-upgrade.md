# Major Version Upgrade Lab

## Objective

- Upgrade from Postgrest 16 to 17

## Take a full backup

Edit the `spec.backups.pgbackrest.manual` section of the manifest located in
`hippo/prod/hippo-pg.yaml` file.  Modify the `type` to be full.

```text
spec:
  backups:
    pgbackrest:
      manual:
        repoName: repo1
        options:
        - --type=full
```

Apply the updated manifest.

```shell
kubectl apply -k hippo/prod
```

Start a full backup by annotating the hippo custom resource.

```shell
kubectl annotate postgrescluster hippo  --overwrite postgres-operator.crunchydata.com/pgbackrest-backup="$( date '+%F_%H:%M:%S' )"
```

## Create pgUpgrade custom resource

To perform an upgrade, there is another customer resource called `PGUpgrade`.  This custom resource
describes the upgrade to the Operator.  View the `hippo/prod/hippo-upgrade.yaml` file to
see the upgrade manifest.

After viewing, apply the manifest.

```shell
kubectl apply -f hippo/prod/hippo-upgrade.yaml
```

Check the status of the upgrade by descibing the resource.

```shell
kubectl describe pgupgrade hippo-upgrade
```

You will notice that the current status indicates the upgrade is waiting for the Postgres cluster 
to be shutdown.

## Shudown cluster and start upgrade

Patch the hippo custom resource to shutdown the cluster.

```shell
kubectl patch postgrescluster hippo --type merge --patch '{"spec":{"shutdown": true}}'
```

Annotate the hippo resource to trigger the upgrade.

```shell
kubectl annotate postgrescluster hippo postgres-operator.crunchydata.com/allow-upgrade="hippo-upgrade"
```

## Monitor upgrade

To monitor the upgrade, check the status of the pgupgrade customer resource.

```shell
kubectl describe pgupgrade hippo-upgrade
```

Once the upgrade job completes and the Reason `PGUpgradeSucceeded` has a Status of `True` the upgrade is complete.

Once the status shows complete, check the upgrade pod log.

```shell
kubectl logs $(kubectl get pod -l postgres-operator.crunchydata.com/role=pgupgrade -o name)
```

## Restart Postgres

Edit the `hippo/prod/hippo-pg.yaml` file and update the `image` to the 17 image (comment out 16 images and uncomment out 17 image).

Also update the `postgresVersion` from 16 to 17.

```text
spec:
  #image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres:ubi9-16.8-2516
  #image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres:ubi9-16.9-2520
  image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres:ubi9-17.5-2520  
  postgresVersion: 17
  shutdown: false
```

Apply the updated manifest (which will also reset the shutdown flag to false).

```shell
kubectl apply -k hippo/prod
```

## Check version

```shell
export PGPASSWORD=$(kubectl get secret hippo-pguser-appuser --template={{.data.password}} | base64 --decode)

psql -U appuser -h hippo-primary.postgres-operator -c "select version()" -d appdev
```

## Execute post upgrade tasks

Perform vacuum analyze.

```shell
kubectl exec -c database -it $(kubectl get pod -l postgres-operator.crunchydata.com/role=master -o name) -- /usr/pgsql-17/bin/vacuumdb --all --analyze-in-stages
```

Upgrade extensions.

```shell
kubectl exec -c database -it $(kubectl get pod -l postgres-operator.crunchydata.com/role=master -o name)  -- psql -f /pgdata/update_extensions.sql
```

Note that some extensions will fail to upgrade and must be dropped and recreated (pgaudit most common).

Delete old cluster

```shell
kubectl exec -c database -it $(kubectl get pod -l postgres-operator.crunchydata.com/role=master -o name) -- /pgdata/delete_old_cluster.sh
```

Take full backup

```shell
kubectl annotate postgrescluster hippo --overwrite postgres-operator.crunchydata.com/pgbackrest-backup="$( date '+%F_%H:%M:%S' )"
```
