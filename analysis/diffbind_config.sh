#!/usr/bin/env bash
# Script to prepare configuration csv for diffbind
# author Oleg Shpynov (oleg.shpynov@jetbrains.com)

>&2 echo "diffbind_config: $@"
if [ $# -lt 2 ]; then
    echo "Need 2 parameters! <WORKING_FOLDER> <NAME> <Q>"
    echo "Example: scratch/artyomov_lab_aging/Y10OD10/chipseq/processed k27ac_10vs10"
    echo "Necessary folders: \${NAME}_bams, \${NAME}_bams_macs_broad_\$Q"
    exit 1
fi
WORK_DIR=$1
NAME=$2
Q=$3

cd $WORK_DIR
READS_DIR=${NAME}_bams
PEAKS_DIR=${NAME}_bams_macs_broad_${Q}

>&2 echo "WORK_DIR: $WORK_DIR"
if [[ ! -d ${WORK_DIR} ]]; then
    echo "Missing folder ${WORK_DIR}"
    exit 1
fi
>&2 echo "READS_DIR: $READS_DIR"
if [[ ! -d ${READS_DIR} ]]; then
    echo "Missing folder ${READS_DIR}"
    exit 1
fi
>&2 echo "PEAKS_DIR: $PEAKS_DIR"
if [[ ! -d ${PEAKS_DIR} ]]; then
    echo "Missing folder ${PEAKS_DIR}"
    exit 1
fi

# Start with reads, so that we can move outliers to separate folders and process only valid data
READS_FILES=$(find $READS_DIR -name "*.bam" | grep -v input | sort)
echo "SampleID,Tissue,Factor,Condition,Replicate,bamReads,ControlID,bamControl,Peaks,PeakCaller"
for R in $READS_FILES; do
    >&2 echo "READ: $R"
    FNAME=${R##*/}
    # Should be changed for particular naming scheme
    SAMPLE=${FNAME%%_K9me3.bam}
    >&2 echo "SAMPLE: $SAMPLE"
    CONDITION=${SAMPLE%%D*}
    >&2 echo "CONDITION: $CONDITION"
    REPLICATE=${SAMPLE##*D}
    >&2 echo "REPLICATE: $REPLICATE"
    READ=$(ls $READS_DIR/${SAMPLE}*.bam)
    >&2 echo "READ: $READ"
    CONTROL=$(ls $READS_DIR/${CONDITION}*input*.bam)
    >&2 echo "CONTROL: $CONTROL"
    PEAK=$(ls $PEAKS_DIR/${SAMPLE}*.xls)
    >&2 echo "PEAK: $PEAK"
    echo "$SAMPLE,CD14,Age,$CONDITION,$REPLICATE,$WORK_DIR/$READ,${CONDITION}_pooled,$WORK_DIR/$CONTROL,$WORK_DIR/${PEAK},macs"
done