#!/usr/bin/env bash

>&2 echo "run_diff_macs_pooled: $@"
if [ $# -ne 2 ]; then
    echo "Need 2 parameters! <NAME> <WORKDIR>"
    exit 1
fi


NAME=$1

BROAD_CUTOFF=0.1

FOLDER=$2

READS_Y=$(find . -name 'YD*.bam' | sed 's#\./##g' | grep -v 'input')

INPUTS_Y=YD_input.bam

READS_O=$(find . -name 'OD*.bam' | sed 's#\./##g' | grep -v 'input')

INPUTS_O=OD_input.bam

cd $FOLDER

echo "FOLDER"
echo $FOLDER

DIFF_MACS_POOLED="${FOLDER}/diff_macs_pooled"

if [ ! -d $DIFF_MACS_POOLED ]; then
    mkdir -p ${DIFF_MACS_POOLED}
    cd ${DIFF_MACS_POOLED}
    echo "Processing MACS2 pooled peaks and compare them";

    run_parallel << SCRIPT
#!/bin/sh
#PBS -N ${NAME}_Y_macs2_broad_${BROAD_CUTOFF}
#PBS -l nodes=1:ppn=8,walltime=24:00:00,vmem=16gb
#PBS -j oe
#PBS -o ${DIFF_MACS_POOLED}/${NAME}_Y_macs2_broad_${BROAD_CUTOFF}.log
# This is necessary because qsub default working dir is user home
cd ${DIFF_MACS_POOLED}
macs2 callpeak -t $READS_Y -c $INPUTS_Y -f BAM -g hs -n Y_${BROAD_CUTOFF} -B --broad --broad-cutoff ${BROAD_CUTOFF}
SCRIPT
    QSUB_ID1=$QSUB_ID

    run_parallel << SCRIPT
#!/bin/sh
#PBS -N ${NAME}_O_macs2_broad_${BROAD_CUTOFF}
#PBS -l nodes=1:ppn=8,walltime=24:00:00,vmem=16gb
#PBS -j oe
#PBS -o ${DIFF_MACS_POOLED}/${NAME}_O_macs2_broad_${BROAD_CUTOFF}.log
# This is necessary because qsub default working dir is user home
cd ${DIFF_MACS_POOLED}
macs2 callpeak -t $READS_O -c $INPUTS_O -f BAM -g hs -n O_${BROAD_CUTOFF} -B --broad --broad-cutoff ${BROAD_CUTOFF}
SCRIPT
    QSUB_ID2=$QSUB_ID
    wait_complete "$QSUB_ID1 $QSUB_ID2"

    check_logs
    bash ${SCRIPT_DIR}/bed/compare.sh Y_${BROAD_CUTOFF}_peaks.broadPeak O_${BROAD_CUTOFF}_peaks.broadPeak ${NAME}_${BROAD_CUTOFF}
fi
