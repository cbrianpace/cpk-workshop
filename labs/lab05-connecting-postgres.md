# Connecting to Postgres Lab

## Objectives

- Connect within Kuberenetes to Postgres

## Connecting to Postgres

### View Services

View the services, this will be the entrypoint to Postgres.

```shell
kubectl get services
```

### Connect with PSQL

Set an environment variable with the password for the hippo user.

```shell
export PGPASSWORD=$(kubectl get secret hippo-pguser-hippo --template={{.data.password}} | base64 --decode)
```

Finally, connect to Postgres using psql.

```shell
psql "postgresql://hippo@hippo-primary.postgres-operator.svc.cluster.local:5432/hippo?sslmode=require"
```

Type `exit` to exit out of psql.
