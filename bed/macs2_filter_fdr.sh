#!/usr/bin/env bash
# This script is used to filter peaks by given FDR from given MACS2 peaks folder
# author Oleg Shpynov (oleg.shpynov@jetbrains.com)

>&2 echo "macs2_filter_fdr.sh: $@"

if [ $# -lt 4 ]; then
    echo "Need 4 parameters! <PEAKS_FOLDER> <OUTPUT_FOLDER> <Q_SOURCE> <Q_TARGET>"
    exit 1
fi

PEAKS_FOLDER=$1
OUTPUT_FOLDER=$2
Q_SOURCE=$3
Q_TARGET=$4
Q_MLOG10=$(echo "-l($Q_TARGET)/l(10)" | bc -l)

if [[ ! -d ${PEAKS_FOLDER} ]]; then
    echo "Missing folder ${PEAKS_FOLDER}"
    exit 1
fi
mkdir -p ${OUTPUT_FOLDER}

cd ${PEAKS_FOLDER}
for F in $(ls *.*Peak | grep -v gapped); do
    NAME=${F%%${Q_SOURCE}*}
    EXT=${F##*_peaks.}
    NEWF=${OUTPUT_FOLDER}/${NAME}${Q_TARGET}_peaks.${EXT}
    echo "$F > $NEWF"
    cat $F | awk -v OFS='\t' -v NAME=$NAME -v Q_TARGET=$Q_TARGET -v Q_MLOG10=$Q_MLOG10 \
    'BEGIN {i=1} ($9 > Q_MLOG10) {print($1,$2,$3,sprintf("%s%s_peak_%d",NAME,Q_TARGET,i),$5,$6,$7,$8,$9,$10);i=i+1}' > $NEWF
done

