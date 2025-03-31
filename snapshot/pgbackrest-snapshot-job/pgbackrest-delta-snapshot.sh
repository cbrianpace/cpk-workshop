#!/bin/bash

echo "Starting pgBackrest Delta Snapshot Process"

# Environment variables:
#   DELTA_PVC:            Source PVC for snapshot.
#   SNAPSHOT_RETRYCOUNT:  Number of times to check for snapshot completion.
#   SNAPSHOT_SLEEP:       Number of seconds to sleep between checks.

: "${SNAPSHOT_RETRYCOUNT:=60}"
: "${SNAPSHOT_SLEEP:=10}"
: "${POSTGRESQL_VERSION:=16}"

export TOKEN=`cat /run/secrets/kubernetes.io/serviceaccount/token`

# Wait for Snapshot
#   Relies on env var SNAPSHOT_NAME
snapshot_wait_for_status() {
    LOOPCNT=1
    SNAPCOMPLETE=0

    while [[ $SNAPCOMPLETE -ne 1 ]]
    do
        SNAPSHOTSTATUS=$(curl -k -H "Authorization:  Bearer $TOKEN" https://${KUBERNETES_SERVICE_HOST}/apis/snapshot.storage.k8s.io/v1/namespaces/${DELTA_NAMESPACE}/volumesnapshots/${SNAPSHOT_NAME} 2> /dev/null | grep "readyToUse" | tr -d '\n')

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

#
# Check Backup Label
#
BACKUP_LABEL="xxx"

if [ -e "/pgdata/pg${POSTGRESQL_VERSION}/backup_label" ]
then
  BACKUP_LABEL=$(md5sum /pgdata/pg${POSTGRESQL_VERSION}/backup_label | awk '{print $1}')
fi

#
# Perform Delta Restore
#
echo "Starting pgBackRest delta restore"

pgbackrest restore --stanza=db --pg1-path=/pgdata/pg${POSTGRESQL_VERSION} --type=none --repo=1 --delta --link-all --log-level-console=detail

#
# Check Backup Label - Post
#
BACKUP_LABEL_POST="xxx"

if [ -e "/pgdata/pg${POSTGRESQL_VERSION}/backup_label" ]
then
  BACKUP_LABEL_POST=$(md5sum /pgdata/pg${POSTGRESQL_VERSION}/backup_label | awk '{print $1}')
fi

#
# Perform Snapshot
#
if [ "$BACKUP_LABEL" != "$BACKUP_LABEL_POST" ]
then
  SNAPSHOT_NAME="hippo-deltarestore-snapshot-$(date +%Y%m%d%H%M)"

  echo "  Perform Sanpshot of PVC ${DELTA_PVC} with snapshot name ${SNAPSHOT_NAME}"

  SNAPPAYLOAD="{ \
    \"apiVersion\": \"snapshot.storage.k8s.io/v1\", \
    \"kind\": \"VolumeSnapshot\", \
    \"metadata\": \
      { \
        \"name\": \"${SNAPSHOT_NAME}\", \
        \"namespace\": \"${DELTA_NAMESPACE}\" \
      }, \
    \"spec\": \
      { \
        \"volumeSnapshotClassName\": \"${VOLUME_SNAPSHOT_CLASS}\", \
        \"source\": { \"persistentVolumeClaimName\": \"${DELTA_PVC}\" } \
      } \
  }"

  echo "Snapshot Payload:"
  echo $SNAPPAYLOAD

  # curl -k -XPOST -H "Authorization:  Bearer $TOKEN" \
  #     -H "Content-Type: application/json" -d "$SNAPPAYLOAD" \
  #     https://${KUBERNETES_SERVICE_HOST}/apis/snapshot.storage.k8s.io/v1/namespaces/${DELTA_NAMESPACE}/volumesnapshots > /dev/null 2> /dev/null

  response_code=$(curl -k -XPOST -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" -d "$SNAPPAYLOAD" \
      -o /tmp/curl.log -s -w "%{http_code}" \
      https://${KUBERNETES_SERVICE_HOST}/apis/snapshot.storage.k8s.io/v1/namespaces/${DELTA_NAMESPACE}/volumesnapshots)

  if [[ $? -ne 0 ]]; then
      echo "Curl command failed"
      exit 1
  elif [[ "$response_code" -ge 200 && "$response_code" -lt 300 ]]; then
      echo "Success: Received HTTP $response_code"
  else
      echo "Error: Received HTTP $response_code"
      cat /tmp/curl.log
      exit 1
  fi

  #
  # Wait for Snapshot to Complete
  #
  echo "  Waiting for snapshot to complete"
  sleep ${SNAPSHOT_SLEEP}
  snapshot_wait_for_status
  echo " "
else
  echo "Database was not advanced by restore, skipping storage snapshot"
fi

echo "Complete"