shopt -s xpg_echo

while (true)
do
    KUBEOUT=`kubectl get pod -L postgres-operator.crunchydata.com/role -l postgres-operator.crunchydata.com/instance -L postgres-operator.crunchydata.com/cluster | grep -v "NAME" | sed 's/\ \  */,/g' | awk -F "," '{print $7"."$1"."$6}' | sort`
    CLUSTERNAME=""
    CLUSTERNAMEPREV=""
    NOCLUSTER="\nCluster: none\n"
    FINALOUT="`date`\n"
    while IFS=$'\n' read OUTPUT
    do
        CLUSTERNAME=`echo $OUTPUT | awk -F "." '{print $1}'`
        if [ "$CLUSTERNAME" != "$CLUSTERNAMEPREV" ]
        then
           if ! [[ -z "$CLUSTERNAME" ]]
           then
                FINALOUT+="\n"
                FINALOUT+="Cluster: $CLUSTERNAME\n"
                CLUSTERNAMEPREV=$CLUSTERNAME
            fi
        fi

        TEMPOUT=`echo $OUTPUT  | awk -F "." '{if ($3=="master") {print $2 "  🟩   leader    "} else if ($3=="primary") {print $2 "  🟩   standby leader"} else if ($3=="replica") {print $2 "  🟦    ...  replica    "} else {print $2 "  🟥   down    "}}'`

        if [[ -z "$CLUSTERNAME" ]]
        then
            NOCLUSTER+="${TEMPOUT}\n"
        else
            FINALOUT+="${TEMPOUT}\n"
        fi
    done <<< "$(echo "$KUBEOUT" | grep -v NAME )"


    KUBEOUT=`kubectl get pod -L postgres-operator.crunchydata.com/role -l job-name -L postgres-operator.crunchydata.com/cluster | grep -v "Error" | grep -v "Complete" | grep -v "NAME" | sed 's/\ \  */,/g' | awk -F "," '{print $7"."$1"."$6}' | sort`
    CLUSTERNAME=""
    CLUSTERNAMEPREV=""
    JOBOUT="\nJobs: \n"
    while IFS=$'\n' read OUTPUT
    do
        CLUSTERNAME=`echo $OUTPUT | awk -F "." '{print $1}'`
        if [ "$CLUSTERNAME" != "$CLUSTERNAMEPREV" ]
        then
           if ! [[ -z "$CLUSTERNAME" ]]
           then
                JOBOUT+="\n"
                JOBOUT+="Cluster: $CLUSTERNAME\n"
                CLUSTERNAMEPREV=$CLUSTERNAME
            fi
        fi
        TEMPJOBOUT=`echo $OUTPUT  | awk -F "." '{print $2}'`
        JOBOUT+="${TEMPJOBOUT}\n"
    done <<< "$(echo "$KUBEOUT" | grep -v NAME )"


    clear
    echo ${FINALOUT}${NOCLUSTER}${JOBOUT}
    echo
    echo

    sleep 2
done
