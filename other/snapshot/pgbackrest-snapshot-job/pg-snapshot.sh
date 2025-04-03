#!/bin/bash

# Environment variables:
#   CHECK_RETRYCOUNT:     Number of times a status check will wait.
#   CHECK_SLEEP:          Number of seconds to sleep between checks.
#   SNAPSHOT_RETRYCOUNT:  Number of times to check for snapshot completion.
#   SNAPSHOT_SLEEP:       Number of seconds to sleep between checks.

: "${CHECK_RETRYCOUNT:=12}"
: "${CHECK_SLEEP:=10}"
: "${SNAPSHOT_RETRYCOUNT:=60}"
: "${SNAPSHOT_SLEEP:=10}"


# Wait for Postgres to be in Desired State
#   arg 1: Host
#   arg 2: Port
#   arg 3: State (1 for up, 0 for down)
check_postgres_replica_state() {
    LOOPCNT=1
    DESIREDSTATE=$3

    while [[ $(check_postgres_status $REPLICA_HOST $REPLICA_PORT) -ne $DESIREDSTATE ]]
    do
        ((LOOPCNT++))
        sleep $CHECK_SLEEP

        if [ $LOOPCNT -gt $CHECK_RETRYCOUNT ]
        then
            echo "Replica did not restart after snapshot."
            exit 1
        fi

    done
}

# Check Postgres Status
#   arg 1: Host
#   arg 2: Port
check_postgres_status () {
    echo $(pg_isready -h $1 -p $2 | grep -c "\- accepting connections")
}

# Modify the shutdown parameter
#   arg 1: true|false
postgres_cluster_change_shutdown() {
    curl -k -XPATCH -H "Authorization:  Bearer $TOKEN" \
     -H "Content-Type: application/json-patch+json" -d "[{ \"op\": \"replace\", \"path\": \"/spec/shutdown\", \"value\": $1 }]" \
     https://${KUBERNETES_SERVICE_HOST}/apis/postgres-operator.crunchydata.com/v1beta1/namespaces/${REPLICA_NAMESPACE}/postgresclusters/${REPLICA_CLUSTER} > /dev/null 2> /dev/null
}

# Wait for Snapshot
#   Relies on env var SNAPSHOT_NAME
snapshot_wait_for_status() {
    LOOPCNT=1
    SNAPCOMPLETE=0

    while [[ $SNAPCOMPLETE -ne 1 ]]
    do
        SNAPSHOTSTATUS=$(curl -k -H "Authorization:  Bearer $TOKEN" https://${KUBERNETES_SERVICE_HOST}/apis/snapshot.storage.k8s.io/v1/namespaces/${REPLICA_NAMESPACE}/volumesnapshots/${SNAPSHOT_NAME} 2> /dev/null | grep "readyToUse" | tr -d '\n')

        echo "    Snapshot Status: ${SNAPSHOTSTATUS} - Check ${LOOPCNT} of ${SNAPSHOT_RETRYCOUNT}"

        SNAPCOMPLETE=$(echo ${SNAPSHOTSTATUS} | grep -c "true")

        ((LOOPCNT++))
        sleep $SNAPSHOT_SLEEP

        if [ $LOOPCNT -gt $SNAPSHOT_RETRYCOUNT ]
        then
            echo "Timeout waiting for snapshot.  Aborting snapshot"
            exit 1
        fi

    done
}

echo "Starting Postgres Replica Snapshot Process"

export TOKEN=`cat /run/secrets/kubernetes.io/serviceaccount/token`
export SOURCE_HOST="${SOURCE_CLUSTER}-primary.${SOURCE_NAMESPACE}"
export REPLICA_HOST="${REPLICA_CLUSTER}-primary"

#
# Verify Replica Source is UP
#
echo "  Verifing Replica is Up"
if [[ $(check_postgres_status $REPLICA_HOST $REPLICA_PORT) -ne 1 ]]
then
    echo "Replica source is not up.  Aborting snapshot"
    exit 1
fi

#
# Check Replication Status
#
echo "  Verifing Replica (${REPLICA_HOST}:${REPLICA_PORT}) is insync with Source (${SOURCE_HOST}:${SOURCE_PORT})"

SOURCELSN=$(psql -a -t -n -E -h $SOURCE_HOST -p $SOURCE_PORT -c "select pg_current_wal_lsn()::text" | grep -v select)

echo "    Source at LSN ${SOURCELSN}"

REPLICACURRENT="f"
LOOPCNT=1

while [[ $REPLICACURRENT = "f" ]]
do
    REPLICALSN=$(psql -a -t -n -E -h $REPLICA_HOST -p $REPLICA_PORT -c "select pg_last_wal_replay_lsn()" | grep -v select)
    
    echo "    Replica at LSN ${REPLICALSN} - Check ${LOOPCNT} of ${CHECK_RETRYCOUNT}"

    REPLICACURRENT=$(psql -a -t -n -E -h $REPLICA_HOST -p $REPLICA_PORT -c "select pg_last_wal_replay_lsn() >= trim('$SOURCELSN')::pg_lsn AS is_current" | grep -v select | tr -d ' ')

    ((LOOPCNT++))
    sleep $CHECK_SLEEP

    if [ $LOOPCNT -gt $CHECK_RETRYCOUNT ]
    then
        echo "Replica is not current with source.  Aborting snapshot"
        exit 1
    fi

done

#
# Shutdown Replica
#
echo "  Shutting down Replica"
postgres_cluster_change_shutdown true

#
# Verify Replica Source is Down
#
check_postgres_replica_state $REPLICA_HOST $REPLICA_PORT 0

#
# Perform Snapshot
#
REPLICA_PVC=$(curl -k -H "Authorization:  Bearer $TOKEN" https://${KUBERNETES_SERVICE_HOST}/api/v1/namespaces/${REPLICA_NAMESPACE}/persistentvolumeclaims?labelSelector=postgres-operator.crunchydata.com%2Fdata%3Dpostgres 2> /dev/null | grep pgdata | grep name | awk -F ":" '{print $2}' | tr -d '", ')

SNAPSHOT_NAME="acmeprod-replica-snapshot-$(date +%Y%m%d%H%M)"

echo "  Perform Sanpshot of PVC ${REPLICA_PVC} with snapshot name ${SNAPSHOT_NAME}"

SNAPPAYLOAD="{ \
  \"apiVersion\": \"snapshot.storage.k8s.io/v1\", \
  \"kind\": \"VolumeSnapshot\", \
  \"metadata\": \
    { \
      \"name\": \"${SNAPSHOT_NAME}\", \
      \"namespace\": \"${REPLICA_NAMESPACE}\", \
      \"annotations\": \
        { \
          \"snapshot.storage.kubernetes.io/pvc-access-modes\": \"ReadWriteOnce\", \
          \"snapshot.storage.kubernetes.io/pvc-storage-class\": \"ssd-csi\", \
          \"snapshot.storage.kubernetes.io/pvc-volume-mode\": \"Filesystem\" \
        } \
    }, \
  \"spec\": \
    { \
      \"volumeSnapshotClassName\": \"csi-gce-pd-vsc\", \
      \"source\": { \"persistentVolumeClaimName\": \"${REPLICA_PVC}\" } \
    } \
}"

curl -k -XPOST -H "Authorization:  Bearer $TOKEN" \
    -H "Content-Type: application/json" -d "$SNAPPAYLOAD" \
    https://${KUBERNETES_SERVICE_HOST}/apis/snapshot.storage.k8s.io/v1/namespaces/${REPLICA_NAMESPACE}/volumesnapshots > /dev/null 2> /dev/null

#
# Wait for Snapshot to Complete
#
echo "  Waiting for snapshot to complete"
sleep ${SNAPSHOT_SLEEP}
snapshot_wait_for_status
echo " "

#
# Start Replica
#
echo "  Restart replica"
postgres_cluster_change_shutdown false


#
# Verify Replica Source is Up
#
check_postgres_replica_state $REPLICA_HOST $REPLICA_PORT 1

echo "Snapshot complete"