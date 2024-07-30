kubectl exec -it -c database $(kubectl get pod -l postgres-operator.crunchydata.com/role=master -o name) -- pgbench --initialize --scale=10 postgres

kubectl exec -it -c database $(kubectl get pod -l postgres-operator.crunchydata.com/role=master -o name) -- pgbench --time=300 -c 10 postgres

