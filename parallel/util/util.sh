#!/usr/bin/env bash
# author oleg.shpynov@jetbrains.com

# MOCK for module command
type module &>/dev/null || module() { echo "[mock] module $@"; }

# CHPC (qsub) mock replacement
if which qsub &>/dev/null; then
    # Use function to get rid of command substitution.
    # Command substitution doesn't work well with parallel execution.
    run_parallel()
    {
        # LOAD args to $CMD
        CMD=""
        while read -r line; do CMD+=$line; CMD+=$'\n'; done;
        # Return through global variable here, because we can't use command substitution.
        QSUB_ID=$(qsub <<< "$CMD")
    }

    # Small procedure to wait until all the tasks are finished on the qsub cluster
    # Example of usage: wait_complete $TASKS, where $TASKS is a task ids returned by qsub.
    wait_complete()
    {
        echo "Waiting for tasks..."
        for TASK in $@
        do :
            echo -n "TASK: $TASK"
            # The task id is actually the first numbers in the string
            TASK_ID=$(echo ${TASK} | sed -e "s/\([0-9]*\).*/\1/")
            if [ ! -z "$TASK_ID" ]; then
                while qstat ${TASK_ID} &> /dev/null; do
                    echo -n "."
                    sleep 100
                done;
            fi
            echo
        done
        echo "Done. Waiting for tasks"
    }
else
    if [ -z $WASHU_PARALLELISM ]; then
        WASHU_PARALLELISM=8
    fi
    >&2 echo "Local tasks WASHU_PARALLELISM=$WASHU_PARALLELISM"

    # Local qsub emulation
    qsub()
    {
        # LOAD args to $CMD
        CMD=""
        while read -r line; do CMD+=$line; CMD+=$'\n'; done;

        # MacOS cannot handle XXXX template with ".sh" suffix, also --suffix
        # option not available in BSD mktemp, so let's do some hack
        QSUB_FILE_PREFIX=$(mktemp "${TMPDIR:-/tmp/}qsub.XXXXXXXXXXXX")
        QSUB_FILE="${QSUB_FILE_PREFIX}.sh"
        rm ${QSUB_FILE_PREFIX}

        echo "#This file was generated as QSUB MOCK" > $QSUB_FILE
        echo 'type module &>/dev/null || module() { echo "[mock] module $@"; }' >> $QSUB_FILE
        echo "$CMD" >> $QSUB_FILE
        LOG=$(echo "$CMD" | grep "#PBS -o" | sed 's/#PBS -o //g')
        >&2 echo "LOCAL running TASK: ${QSUB_FILE} LOG: $LOG"
        # Redirect both stderr and stdout to LOG file, don't use output, since we use [run_parallel]
        bash $QSUB_FILE &> "$LOG" &
    }

    run_parallel()
    {
        # Wait until less then $WASHU_PARALLELISM tasks running
        while [ $(jobs | wc -l) -ge $WASHU_PARALLELISM ] ; do sleep 1 ; done

        # LOAD args to $CMD
        CMD=""
        while read -r line; do CMD+=$line; CMD+=$'\n'; done;
        qsub <<< "$CMD"
    }

    wait_complete()
    {
        echo "LOCAL waiting for tasks..."
        wait
        echo "Done. LOCAL waiting for tasks"
    }
fi

# Checks for errors in logs, stops the world
check_logs()
{
    # IGNORE macs2 ValueError
    # See for details: https://github.com/JetBrains-Research/washu/issues/14
    ERRORS=$(find . -name "*.log" | xargs grep -i -E "error|exception|No such file or directory" | grep -v "ValueError")
    if [ ! -z "$ERRORS" ]; then
        echo "ERRORS found"
        echo "$ERRORS"
        exit 1
    fi
}

job_tmp_dir() {
    if [ -z "${PBS_JOBID}" ]; then
      TMP_DIR=~/tmp/job$$;
    else
      TMP_DIR="/tmp/$PBS_JOBID";
    fi
    mkdir -p "${TMP_DIR}"

    echo "${TMP_DIR}"
}

clean_job_tmp_dir() {
    if [ -z "${PBS_JOBID}" ]; then
      rm -rf "$(job_tmp_dir)"
    fi
}