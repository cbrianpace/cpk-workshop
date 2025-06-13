# Operator Installation

## Objectives

- Create a Namespace
- Deploy Postgres Operator

## Deplaoy Operator

### Check access

The following command will return the nodes that make up the cluster.
The Kubernetes cluster is GKE with 2 nodes.

```shell
kubectl get nodes
```

### Create Namespace

The Operator will be deployed into the `postgres-operator` namespace.
The rest of the labs will be performed using this namespace.

```shell
kubectl create namespace postgres-operator
```

Using the following command, set the default namespace to `postgres-operator`.
This is critical as none of the `kubectl` commands going forward include the namespace option
and relies on the default namespace being set.

```shell
kubectl ns postgres-operator
```

### Deploy the Operator

The following command uses the kustomize installer to deploy the Operator.

```shell
kubectl apply --server-side -k operator/install/default
```

Using the next command, monitor the pods and verify that they successfully reach the Ready tate.

```shell
kubectl get pods
```

Kubernetes does not natively know anything about Postgres.  The way the Operator extends
Kubernetes is by adding a new API via the Customer Resource Definition `postgrescluster`.

The Custom Resource is the tool that will be used to describe to the Operator the desired
Postgres configuration.  The Operator will ensure that the actual state matches what is
defined in the `postgrescluster` custom resource.

The following command can be used to explore the customer resource.

```shell
kubectl explain postgrescluster
```
