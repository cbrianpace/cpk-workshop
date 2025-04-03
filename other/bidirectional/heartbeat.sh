while (true)
do
    kubectl exec -it $(kubectl get pod -l postgres-operator.crunchydata.com/role=master,postgres-operator.crunchydata.com/cluster=hreast -o name) -c database -- psql -c "UPDATE heartbeat SET hb_date=current_timestamp WHERE source_db=current_setting('cluster_name')"
    kubectl exec -it $(kubectl get pod -l postgres-operator.crunchydata.com/role=master,postgres-operator.crunchydata.com/cluster=hrwest -o name) -c database -- psql -c "UPDATE heartbeat SET hb_date=current_timestamp WHERE source_db=current_setting('cluster_name')"
    sleep 5
done