#!/usr/bin/env bash

###########################################################################
# Batch fastq-dump & multiqc:
#    Accepts list on one or many fastq containing directories.
#    In each <WORK_DIR> script runs fastqc for all its fastq/fastq.gz files
#    (single or paired ended) saves results to <WORK_DIR>/fastqc directory.
###########################################################################
# author oleg.shpynov@jetbrains.com
# author roman.chernyatchik@jetbrains.com

# Check configuration
[[ ! -z ${WASHU_ROOT} ]] || { echo "ERROR: WASHU_ROOT not configured"; exit 1; }
source ${WASHU_ROOT}/parallel/util.sh

>&2 echo "Batch fastqc $@"
if [[ $# -lt 1 ]]; then
    echo "Need at least one parameter! <WORK_DIR>"
    exit 1
fi
WORK_DIRS="$@"

TASKS=()
for WORK_DIR in ${WORK_DIRS}; do :
    cd ${WORK_DIR}
    WORK_DIR_NAME=${WORK_DIR##*/}
    RESULTS_DIR="${WORK_DIR}/fastqc"
    if [[ -d "${RESULTS_DIR}" ]]; then
        echo "   [Skipped] ${RESULTS_DIR} was already processed"
        continue
    else
        mkdir -p "${RESULTS_DIR}"
    fi

    for FILE in $(find . -name '*.f*q' | sed 's#\./##g' | sort)
    do :
        FILE_NAME=${FILE##*/}
        NAME=${FILE_NAME%%.fast*} # file name without extension
        # Submit task
        run_parallel << SCRIPT
#!/bin/sh
#PBS -N fastqc_${WORK_DIR_NAME}_${NAME}
#PBS -l nodes=1:ppn=1,walltime=2:00:00,vmem=4gb
#PBS -j oe
#PBS -o ${WORK_DIR}/${NAME}_fastqc.log

# Loading modules
module load fastqc

# This is necessary because qsub default working dir is user home
# and our FILE is relative
cd ${WORK_DIR}

# Options:
# -o --outdir     Create all output files in the specified output directory.
#                     Please note that this directory must exist as the program
#                     will not create it. If this option is not set then the
#                      output file for each sequence file is created in the same
#                     directory as the sequence file which was processed.

# TODO: maybe use a couple of threads instead one?
# -t --threads    Specifies the number of files which can be processed
#                     simultaneously. Each thread will be allocated 250MB of
#                     memory so you shouldn't run more threads than your
#                     available memory will cope with, and not more than
#                      6 threads on a 32 bit machine
#
fastqc --outdir "${RESULTS_DIR}" "${FILE}"
SCRIPT
        echo "FILE: ${WORK_DIR_NAME}/${FILE}; TASK: ${QSUB_ID}"
        TASKS+=("$QSUB_ID")
    done
done

wait_complete ${TASKS[@]}
check_logs

for WORK_DIR in ${WORK_DIRS}; do :
    cd ${WORK_DIR}

    echo "Processing multiqc for: ${WORK_DIR}"
    #Options:
    # -f, --force           Overwrite any existing reports
    # -s, --fullnames       Do not clean the sample names (leave as full file name)
    # -o, --outdir TEXT     Create report in the specified output directory.
    multiqc -f -o "${WORK_DIR}" "${WORK_DIR}/fastqc"
done
>&2 echo "Done. Batch fastqc $@"
