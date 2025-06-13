# Backups Lab

## Objectives

- View backup configuration and jobs
- Perform manual backups
- View backup metadata

## View backup configuration and jobs

View the `spec.backups.backrest` section in the `hippo/prod/hippo-pg.yaml` file.

Parameters that control pgBackrest behavior are stored in the `spec.backups.backrest.global` section.

```text
spec:
  backups:
    backrest:
      global:
        archive-copy: "y"
        log-level-console: info
        repo1-retention-full-type: time
        repo1-retention-full: "7"   
        start-fast: "y"     
```

Job schedules are stored under each repo (`spec.backups.backrest.repos.[n].schedule`).

```text
spec:
  backups:
    backrest:
      repos:
      - name: repo1
        schedules:
          full: "0 1 * * 0"
          differential: "0 1 * * 3"
          incremental: "0 1 * * 1,2,4,5,6"          
```

Now view the scheduled Kubernetes cron jobs that were created by the Operator.

```shell
kubectl get cronjobs
```

When the cluster is created, an initial backup is automatically performed.  Use the following command
to view backup jobs.

```shell
kubectl get pod -l postgres-operator.crunchydata.com/pgbackrest-backup -L postgres-operator.crunchydata.com/pgbackrest-repo,postgres-operator.crunchydata.com/pgbackrest-backup
```

## Backup lab setup

Open a new terminal and start the insert loop script.  The insert loop script will insert rows every 1 minute into the `test`
table.  This will allow us to verify our point in time recoveries in the next lab.  Leave this insert script running
in the new terminal.

```shell
./insert-loop.sh
```

## Manual full backup

View the `hippo/prod/hippo-pg.yaml` file and look at the `spec.backups.pgbackrest.manual` section.
This section informs the Operator what options to use during a manual backup.

```text
spec:
  backups:
    pgbackrest:
      manual:
        repoName: repo1
        options:
        - --type=full
```

Start a manual backup by annotating the `postgrescluster` hippo resource.

```shell
kubectl annotate postgrescluster hippo postgres-operator.crunchydata.com/pgbackrest-backup="$( date '+%F_%H:%M:%S' )"
```

Monitor the pods to watch the backup run.

```shell
kubectl get pod -l postgres-operator.crunchydata.com/pgbackrest-backup -L postgres-operator.crunchydata.com/pgbackrest-repo,postgres-operator.crunchydata.com/pgbackrest-backup
```

## View backups

There are three main ways to view the backups.  First, is via the Grafana `Backup` dashboard.  The other two are by using pgbackrest command 
or the PGO kubectl plugin.

The following command execs into the Backrest pod and using the `pgbackrest` command.

```shell
kubectl exec hippo-repo-host-0 -- pgbackrest info
```

## Incremental backup

Next, perform an incremental backup.  The first step is to modify the default manual
backup actions in the `hippo-pg.yaml` manifest.  Edit the `hippo/prod/hippo-pg.yaml`
file and under `spec.backups.pgbackrest.manual.options` set the type to `incr`.

```text
spec:
  backups:
    pgbackrest:
      manual:
        repoName: repo1
        options:
        - --type=incr
```

Apply the updated manifest.

```shell
kubectl apply -k hippo/prod
```

Now initiate another manual backup.

```shell
kubectl annotate postgrescluster hippo --overwrite postgres-operator.crunchydata.com/pgbackrest-backup="$( date '+%F_%H:%M:%S' )"
```

Monitor the new backup job.

```shell
kubectl get pod -l postgres-operator.crunchydata.com/pgbackrest-backup -L postgres-operator.crunchydata.com/pgbackrest-repo,postgres-operator.crunchydata.com/pgbackrest-backup
```

This time, view the backups using the PGO kubectl plugin.

```shell
kubectl pgo show backup hippo
```
