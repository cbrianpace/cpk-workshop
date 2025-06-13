# Monitoring Lab

## Objectives

- Deploy monitoring stack
- Create load on Postgres cluster
- View dashboards

## Create Namespace

Grafana and Prometheus will be deployed into the `pgmonitor` namespace.

The following command will create the namespace.

```shell
kubectl create namespace pgmonitor
```

## Deploy pgMonitor

The following command will use kustomize to deploy the pgMonitor stack.

```shell
kubectl apply -k monitoring
```

Monitor the pods until they have all successfully reached Ready state.

```shell
kubectl get pods -n pgmonitor
```

Next, using the patch command of `kubectl`, modify the Grafana service to be
of type `LoadBalancer`.

```shell
kubectl patch service crunchy-grafana -n pgmonitor -p '{"spec":{"type": "LoadBalancer"}}'
```

Last, get the external IP address for the service.

```shell
kubectl get services -n pgmonitor -w
```

## Create load on Postgres

Before starting the load, look again at the yaml file for the hippo cluster (hippo/prod/hippo-pg.yaml).

Notice the spec.monitoring section where the exporter is defined.  This tells the Operator to include 
the Prometheus exporter container in the pod.

Now, use the following to create a load on the database.  The load will run for about 5 minutes.

```shell
./pgbench.sh
```

With pgbench running, navigate to the Grafana dashboards and navigate to `Dashboards`->`Browse` using the 
side navigation menu and explore the Crunchy provided dashboards.  

The default username and password for Grafana is admin/admin.

http://<loadbalancerIP>:3000
