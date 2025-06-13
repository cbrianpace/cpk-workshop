# Clone Lab

## Objectives

- Create full clone of hippo/prod
- Create PITR clone of hippo/prod

Note:  In this lab we will be working with two different clusters `hippo/prod` and `hippo/dev`.  
       The steps will point out which cluster the actions should be performed against.

## Create full clone

View `spec.dataSource` section of the `hippo/dev` Postgres manifest which is the file
`hippo/dev/hippo-dev-pg.yaml`.

The `spec.dataSource` has many options that can control what the source is for the clone.

```text
  dataSource:
    postgresCluster:
      clusterName: hippo
      repoName: repo1
```

To create the clone, apply the `hippo/dev` manifest.

```shell
kubectl apply -k hippo/dev
```

Watch the pods.

```shell
kubectl get pods -w
```

Press `ctrl-C` to stop the get pods command.

Once the development cluster is online, check the `test` table to verify the clone.

```shell
export PGPASSWORD=$(kubectl get secret hippo-pguser-appuser --template={{.data.password}} | base64 --decode)

psql -U appuser -h hippo-dev-primary.postgres-operator -c "select * from test order by 1 desc limit 10"
```

In the output of the SELECT against the `test` table, pick one of the timestamps and make a copy of it.  Only copy
through the seconds and leave off the fractions of a second.  There is a space below to capture the selected time.

Time picked:  2025-06-13 19:37:28

Now, delete the `hippo/dev` cluster.

```shell
kubectl delete -k hippo/dev
```

## Clone PITR

Using the timestamp captured from the full clone, let's perform a PITR clone.

Edit the `hippo/dev` Postgres manifest (`hippo/dev/hippo-dev-pg.yaml`).  Locate the
`spec.dataSource` section and uncomment out the `options` section.  Modify
the timestamp in the manifest with the timestamp captured above.

```text
  dataSource:
    postgresCluster:
      clusterName: hippo
      repoName: repo1
      options:
        - --type=time
        - --target="2025-06-13 19:37:28"
```

With the manifest updated.  Apply the manifest and wait for the clone to complete.

```shell
kubectl apply -k hippo/dev
```

Optionally, watch the pods.

```shell
kubectl get pods -w
```

Use `ctrl-C` to stop the get pods command.

Now check the `test` table to verify if the PITR clone was successful.

```shell
psql -U appuser -h hippo-dev-primary.postgres-operator -c "select * from test order by 1 desc limit 10"
```

Last, delete the `hippo/dev` cluster.

```shell
kubectl delete -k hippo/dev
```
