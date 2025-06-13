# Modify Postgres Cluster

## Objectives

- Scale cluster
- Shutdown and Restart cluster
- Modify Postgres parameters
- Manage users and databases
- Use initization script

## Scale cluster

Edit the `hippo/prod/hippo-pg.yaml` file and increase replicas from 2 to 4. 

```text
spec:
    instances:
        - name: pga
        replicas: 4
```

After saving your changes apply the updated manifest and monitor the pods as the Operator scales the cluster up.

```shell
kubectl apply -k hippo/prod

kubectl get pods

kubectl get pod -L postgres-operator.crunchydata.com/role -l postgres-operator.crunchydata.com/instance
```

Now, modify the manifest again and change replicas from 4 to 3.

```text
spec:
    instances:
        - name: pga
        replicas: 3
```

Apply changes and monitor pods.

```shell
kubectl apply -k hippo/prod

kubectl get pods

kubectl get pod -L postgres-operator.crunchydata.com/role -l postgres-operator.crunchydata.com/instance
```

## Shutdown and restart cluster

The key `spec.shutdown` can be used to properly shutdown and restart the cluster.  This can be done
by modifying the Postgres manifest and applying, or by use the patch command below.

Note:  Pay attention to the order in which the pods are shutdown when you execute the patch command.

```shell
kubectl patch postgrescluster hippo --type merge --patch '{"spec":{"shutdown": true}}'
```

After the cluster is completely shutdown, restart by execute the following patch command.

Note:  Pay attention to the order in which the pods are restarted.

```shell
kubectl patch postgrescluster hippo --type merge --patch '{"spec":{"shutdown": false}}'
```

## Postgres parameters

Check the current settings for `work_mem` and `shared_buffers`.

```shell
psql -U appuser -d postgres -h hippo-primary.postgres-operator  -c "select name, setting from pg_settings where name in ('work_mem','shared_buffers')"
```

Now, edit the `hippo/prod/hippo-pg.yaml` file and increase the settings for shared_buffers and work_mem.  These can be found under 
the `spec.config.parameters` section.

```text
spec:
  config:
    parameters:
      shared_buffers: 512MB
      work_mem: 8MB          
```

With the changes made, apply the updated manifest.

```shell
kubectl apply -k hippo/prod
```

Check the parameter settings after the change.

```shell
psql -U appuser -d postgres -h hippo-primary.postgres-operator  -c "select name, setting from pg_settings where name in ('work_mem','shared_buffers')"
```

### Trigger a Postgres cluster rolling restart

Sometimes, parameters require the database to be restarted or there may be times that you want to perform a restart. 
The following command can be used to have the Operator perform a rolling restart of the Postgres cluster.

```shell
kubectl patch postgrescluster/hippo -n postgres-operator --type merge --patch '{"spec":{"metadata":{"annotations":{"restarted":"'"$(date)"'"}}}}'
```

## User and Database Management

### Add Users and Databases

Edit the `hippo/prod/hippo-pg.yaml` file and uncomment the user section toward the bottom of the file.

```text
  users:
    - name: appuser
      databases:
        - appdev
        - appuat
```

Once the changes are made apply the new manifest.

```shell
kubectl apply -k hippo/prod
```

Notice the new secret.  Did you notice anything else that changed in with the secrets?

```shell
kubectl get secrets
```

Set the password environment variable to now use the `appuser` and connect to view the users.

```shell
export PGPASSWORD=$(kubectl get secret hippo-pguser-appuser --template={{.data.password}} | base64 --decode)

psql "postgresql://appuser@hippo-primary.postgres-operator.svc.cluster.local:5432/hippo?sslmode=require" -c "\du"
```

Now, view the newly added databases using the following psql command.

```shell
psql "postgresql://appuser@hippo-primary.postgres-operator.svc.cluster.local:5432/hippo?sslmode=require" -c "\l"
```

### Change user passwords

The following command will modify the `hippo-pguser-appuser` secret with a new password.  Notice that the command
clears out the value of the `verifier` key.  This is important.  Failure to clear out the `verifier` key
will not result in the password being changed in the database.

```shell
kubectl patch secret hippo-pguser-appuser -p '{"stringData":{"password":"Welcome1","verifier":""}}'
```

Now, connect with the new password.

```shell
export PGPASSWORD=$(kubectl get secret hippo-pguser-appuser --template={{.data.password}} | base64 --decode)

psql  "user=appuser sslmode=prefer host=hippo-primary.postgres-operator dbname=appdev"
```

## Database initialization script

Using `spec.databaseInitSQL` you can instruct the Operator to execute an initialization script when
it creates the cluster (or when you first add this section or clear the status).

In the `hippo/prod` directory you will notice a file named `init.sql`.  During the kustomize apply
of the cluster, Kustomize has been taking this SQL script and creating a configmap object.  You
can see this by viewing the `hippo/prod/kustomization.yaml` file.

To get the Operator to use this script, uncomment out the `spec.databaseInitSQL` section in
the `hippo/prod/hippo-pg.yaml` file.  

```text
  databaseInitSQL:
    key: init.sql
    name: hippo-init-sql
```

Then apply the changed manifest.

```shell
kubectl apply -k hippo/prod
```

Use the describe command below and review the `Status` section.  One the Operator has executed
the initialization script, a new status entry of `Database Init SQL` will appear.

```shell
kubectl describe postgrescluster hippo
```

The initalization script created some new tables (department, employee, and test).  Use the psql command below the verify the new tables have been created.

```shell
psql -U appuser -d postgres -h hippo-primary.postgres-operator -c "\dt"
```
