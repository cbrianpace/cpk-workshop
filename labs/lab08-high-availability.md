# High Availability Lab

## Objectives

- Observer the 3 levels of HA

## Kubernetes level

The first level of HA is at the Kubernetes level.  This is native Kubernetes behaviour.
To see this in action, kill the backrest pod.

```shell
kubectl delete pod hippo-repo-host-0
```

Now, check the pods and you will see that because of the Statefuleset configuration, the
backrest pod was restarted.

```shell
kubectl get pods
```

## Operator level

The next level is at the Operator level.  At this level the Operator is in a reconcilation loop
and responding to events that causes the actual deployment to deviate  from the declared state.

Delete the primary service.

```shell
kubectl delete service hippo-primary
```

Get a list of the services.

```shell
kubectl get services
```

kubectl delete service hippo-primary

kubectl get services

## Postgres level

The third layer is HA that is built into the containers and is independant of the other layers.
To see this in action, the following steps will log into the leader Postgres pod, remove the
database files, and watch the built in failover and self-healing work.

The following command will exec into the Primary pod and start a bash shell session.

```shell
kubectl exec -it $(kubectl get pod -l postgres-operator.crunchydata.com/role=master -o name) -c database -- bash
```

Next, change the directory to the pgdata directory and list the database files.

```shell
cd /pgdata

ls pg16
```

Now to simulate a failure, remove the Postgres files.

```shell
rm -rf /pgdata/pg16*

ls /pgdata
```

Continue to watch the pod roles and directory and observe the failover and self-healing.

```shell
ls /pgdata/pg16
```
