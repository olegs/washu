#!/usr/bin/env bash
# author oleg.shpynov@jetbrains.com

which rseg &>/dev/null || { echo "rseg not found! Download rseg: <http://smithlabresearch.org/software/rseg/>"; exit 1; }

# Load technical stuff, not available in qsub emulation
if [ -f "$(dirname $0)/util.sh" ]; then
    source "$(dirname $0)/util.sh"
fi

if [ $# -lt 3 ]; then
    echo "Need 3 parameters! <work_dir> <genome> <chrom.sizes>"
    exit 1
fi

WORK_DIR=$1
GENOME=$2
CHROM_SIZES=$3

echo "Batch rseg: ${WORK_DIR} ${GENOME} ${CHROM_SIZES}"
cd ${WORK_DIR}

echo "Prepare chrom_sized.bed"
cat ${CHROM_SIZES} | awk '{print $1, 1, $2}' > ${GENOME}_chrom_sizes.bed

echo "Obtain deadzones file for ${GENOME}"
if [[ ${GENOME} =~ ^hg19$ ]]; then
    DEADZONES="deadzones-k36-hg19.bed"
fi
if [[ ${GENOME} =~ ^mm9$ ]]; then
    DEADZONES="deadzones-k36-mm9.bed"
fi
# Check that DEADZONES are with us
if [[ -z "${DEADZONES}" ]]; then
    echo "Unknown species for rseg: ${GENOME}"
    exit 1
fi
# Download DEADZONES file
if [[ ! -f ${DEADZONES} ]]; then
    wget "http://smithlabresearch.org/data/${DEADZONES}"
fi

TASKS=""
for FILE in $(find . -name '*.bam' | sed 's#./##g' | grep -v 'input')
do :
    INPUT=$(python $(dirname $0)/util.py find_input ${WORK_DIR}/${FILE})
    echo "${FILE} input: ${INPUT}"

    NAME=${FILE%%.bam} # file name without extension

    # Create tmpfile in advance, because of interpolation of qsub call
    FILE_TMP_BED=$(mktemp)

    # Submit task
    QSUB_ID=$(qsub << ENDINPUT
#!/bin/sh
#PBS -N rseg_${NAME}
#PBS -l nodes=1:ppn=8,walltime=24:00:00,vmem=16gb
#PBS -j oe
#PBS -o ${WORK_DIR}/${NAME}_rseg.log

module load bedtools2

# This is necessary because qsub default working dir is user home
cd ${WORK_DIR}

# RSEG works with BED only
# See sort instructions at http://smithlabresearch.org/wp-content/uploads/rseg_manual_v0.4.4.pdf
export LC_ALL=C
bedtools bamtobed -i ${FILE} | sort -k1,1 -k3,3n -k2,2n -k6,6 > ${FILE}.bed

if [ -f "${INPUT}" ]; then
    # Use tmp files to reduced async problems with same input parallel processing
    echo "${FILE}: control file found: ${INPUT}"
    if [ ! -f ${INPUT}.bed ]; then
        bedtools bamtobed -i ${INPUT} | sort -k1,1 -k3,3n -k2,2n -k6,6 > ${FILE_TMP_BED}
        # Check that we are the first in async calls, not 100% safe
        if [ ! -f ${INPUT}.bed ]; then
            mv ${FILE_TMP_BED} ${INPUT}.bed
        fi
    fi

    rseg-diff -c ${GENOME}_chrom_sizes.bed -o ${NAME}_domains.bed -i 20 -v -d ${DEADZONES} -mode 2 ${FILE}.bed ${INPUT}.bed
else
    echo "${FILE}: no control file"
    rseg -c ${GENOME}_chrom_sizes.bed -o ${NAME}_domains.bed -i 20 -v -d ${DEADZONES} ${FILE}.bed
fi
ENDINPUT
)
    echo "FILE: ${FILE}; JOB: ${QSUB_ID}"
    TASKS="$TASKS $QSUB_ID"
done
wait_complete ${TASKS}
check_logs

# Cleanup
for FILE in $(find . -name '*.bam' | sed 's#./##g' | grep -v 'input')
do :
    INPUT=$(python $(dirname $0)/util.py find_input ${WORK_DIR}/${FILE})
    if [ -f "${INPUT}" ]; then
        rm ${INPUT.bed}
    fi
    rm ${FILE}.bed
done

echo "Done. Batch rseg: ${WORK_DIR} ${GENOME} ${CHROM_SIZES}"