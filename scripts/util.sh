#!/usr/bin/env bash
# author oleg.shpynov@jetbrains.com

# CHPC (qsub) mock replacement
which qsub &>/dev/null || {
    echo "CHPC (qsub) system not found, using mock replacement"
    QSUB_MOCK_ENABLED="TRUE"
    qsub() {
        while read -r line; do CMD+=$line; CMD+=$'\n'; done;
        echo "MOCK qsub"
        echo "$CMD" | tee /tmp/qsub.sh
        LOG=$(echo "$CMD" | grep "#PBS -o" | sed 's/#PBS -o //g')
        bash /tmp/qsub.sh | tee "$LOG"
    }
    qstat() {
        echo "MOCK qstat $@"
    }
    module() {
        echo "MOCK module $@"
    }
}

# Small procedure to wait until all the tasks are finished on the qsub cluster
# Example of usage: wait_complete $TASKS, where $TASKS is a task ids returned by qsub.
wait_complete()
{
    echo "Waiting for tasks..."
    if  [ -n $QSUB_MOCK_ENABLED ]
    then
        for TASK in $@
        do :
            echo -n "TASK: $TASK"
            # The task id is actually the first numbers in the string
            TASK_ID=$(echo ${TASK} | sed -e "s/\([0-9]*\).*/\1/")
            if [ ! -z "$TASK_ID" ]; then
                while qstat ${TASK_ID} &> /dev/null; do
                    echo -n "."
                    sleep 10
                done;
            fi
            echo
        done
    fi
    echo "Done."
}

# Checks for errors in logs, stops the world
check_logs()
{
    ERRORS=`find . -name "*.log" | xargs grep -i -e "err"`
    if [ ! -z "$ERRORS" ]; then
        echo "ERRORS found"
        echo "$ERRORS"
        exit 1
    fi
}

# Convert genome to macs2 species encoding
macs2_species()
{
    GENOME=$1
    # Convert Genome build to macs2 species
    [[ ${GENOME} =~ ^hg[0-9]+$ ]] && SPECIES="hs"
    [[ ${GENOME} =~ ^mm[0-9]+$ ]] && SPECIES="mm"
    [[ -z "${SPECIES}" ]] && echo "Unknown species for macs: ${GENOME}" && exit 1
    echo "${SPECIES}"
}