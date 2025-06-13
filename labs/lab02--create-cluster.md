# Create Postgres Cluster

## Objectives

- Create a Postgres cluster
- Deploy Postgres Operator

## Create Cluster

The method to create a highly available and production ready Postgres cluster is
very easy.  All that is needed is to descibe the cluster to the Operator.

This is done by executing the command below to create a new `postgresoperator` instance.

```shell
kubectl apply -k hippo/prod
```

While the cluster is being deployed, view the `hippo/prod/hippo-pg.yaml`.  This is the yaml
file that is used by the `kubectl` command above to create the `postgresoperator` instance.  
The Operator will pick up on this event and respond approriately.

## View what was created

View the pods that are being created.

```shell
kubectl get pods
```

Notice the different pods that are created as well as an initial backup.

## View Kuberenetes objects

Using the following command will show the `postgresoperator` named `hippo`.

```shell
904kubectl get postgrescluster
```

View the stateful sets.

```shell
kubectl get statefulset
```

Last, view the pods.

```shell
kubectl get pods
```
