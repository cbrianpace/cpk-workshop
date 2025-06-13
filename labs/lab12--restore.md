# Restore Lab

## Objectives

- Perform a point in time recovery

Note:  In this lab, we will use the same timestamp that was used in the Clone PITR for `hippo/dev`.  If needed, you can
       grab that timestamp from the `hippo/dev/hippo-dev-pg.yaml` file.

## Restore

Edit the `hippo/prod/hippo-pg.yaml` file and uncomment out the `spec.backups.pgbackrest.restore` section.

Modify the timestamp under the `options` with the same timestamp that was used for the clone PITR in the previous lab.

```text
      restore:
        enabled: true
        repoName: repo1
        options:
          - --type=time
          - --target="2025-06-13 19:37:28"
```

Apply the updated manifest.

```shell
kubectl apply -k hippo/prod
```

Now, trigger the restore by annotating the hippo resource.

```shell
kubectl annotate postgrescluster hippo --overwrite postgres-operator.crunchydata.com/pgbackrest-restore="$( date '+%F_%H:%M:%S' )"
```

Monitor the pods to watch the restore.

```shell
kubectl get pods
```

## Verify data

After the restore is complete, verify the restore was successful.

```shell
psql -U appuser -h hippo-primary.postgres-operator -c "select * from test order by 1 desc limit 10"
```
