# Postgres Objects Lab

## Objectives

- View Cluster State
- User connection information
- Delete Postgres cluster
- Recreate Postgres cluster

## View Cluster State

### View Clusters

One easy way to view all of the clusters is to execute the following command:

```shell
kubectl get postgrescluster --all-namespaces
```

### View Labels

Labels can be used to identify resources related to a specific Postgres cluser.  One of the
most common uses of labels is to determine which pod is the current leader.

```shell
kubectl get $(kubectl get pod -l postgres-operator.crunchydata.com/role=master -o name) -o=jsonpath='{.metadata.labels}' | jq
```

The following command is handy to get the pods and show the current role the pod is playing
in the Postgres HA Cluster.

```shell
kubectl get pod -L postgres-operator.crunchydata.com/role -l postgres-operator.crunchydata.com/instance
```

### View Statefulsets

Why Stateful Sets?  Main reason is better control over the pod names and this is important for the certificate generation.

```shell
kubectl get statefulsets
```

### Services

Servies and endpoints are used for two main purposes.  First, the xxxxx-ha endpoint serves as the quorum device for leader
election.  Second, the services and endpoints work together to route application connections to the correct Postgres
pod/instance.

```shell
kubectl get services
```

```shell
kubectl get endpoints
```

Patroni uses the xxxxx-ha endpoint to manage the leader key and other cluster state information.
The primary and ha service are headless which means the election and endpiont IP are changed in a
single call to the DCS.

The following command will show the current leader information.

```shell
kubectl describe endpoints hippo-ha
```

The replica service will always point to the read-only Postgres instance.  Connections to the replica
service will be routed on a round robin basis the the replica pods/instances.  The replica
service uses a Selector which means it is not a headless service.

```shell
kubectl describe service hippo-replicas
```

### User Secrets

The main secret to be concerned about is the users secrets. Those will follow the pattern of <cluster name>-pguser-<user name>.

```shell
kubectl get secrets
```

Details about how to connecto the Postgres are included in the user secret.  This includes the user name,
password, and various connection URIs.  This allows the application to pull the connection information
from the secret instead of having to be entered manually.

```shell
kubectl get secret hippo-pguser-hippo -o yaml
```

Use the following command to get the password for the `hippo` user.

```shell
export PGPASSWORD=$(kubectl get secret hippo-pguser-hippo --template={{.data.password}} | base64 --decode)

echo $PGPASSWORD
```

### Config Maps

Some of the configuration information from the manifest are translated into various configuration file formats
and stored in the configmaps.  These configmaps are mounted to the approriate containters.  There is no need
to modify these configmaps, but viewing them can be helpful for debugging.

```shell
kubectl get configmaps
```

## Delete Cluster

Before deleting the cluster, note the reclaim policy on the persistent volume.  By default, most have a reclaim policy
of `DELETE`.  This means when the cluster is dropped, so is the storage (and data).

```shell
kubectl get pv
```

The following command will delete the cluster.

```shell
kubectl delete -k hippo/prod
```

Checking all of the objects now will show everything has been deleted.

```shell
kubectl get pods

kubectl get statefulsets

kubectl get postgrescluster --all-namespaces

kubectl get pv
```

## Recreate the Postgres cluster

Finally, recreate the Postgres cluster.

```shell
kubectl apply -k hippo/prod
```
