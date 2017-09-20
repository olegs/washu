#!/bin/bash
# This script is used to compute *minus* of peaks for given 2 files.
#
# What happens:
# - Two peaks aver overlapping if they share at least one nucleotide
# - Prints only peaks that is unique to first file
#
# author Oleg Shpynov (oleg.shpynov@jetbrains.com)

which bedtools &>/dev/null || { echo "bedtools not found! Download bedTools: <http://code.google.com/p/bedtools/>"; exit 1; }
>&2 echo "minus: $@"

if [ $# -lt 2 ]; then
    echo "Need 2 parameters! <FILE1> <FILE2>"
    exit 1
fi

TMP_DIR=~/tmp
mkdir -p "${TMP_DIR}"

FILE1=$1
FILE2=$2
# Folder with source file be read-only, use temp file
SORTED1=$(mktemp)
SORTED2=$(mktemp)
sort -k1,1 -k2,2n -T ${TMP_DIR} $FILE1 > ${SORTED1}
sort -k1,1 -k2,2n -T ${TMP_DIR} $FILE2 > ${SORTED2}

bedtools multiinter -i ${SORTED1} ${SORTED2} |\
 bedtools merge -c 6,7 -o max |\
 # Zero problem: max of '0' is 2.225073859e-308 - known floating point issue in bedtools merge
 awk '{if (NR > 1) printf("\n"); printf("%s\t%s\t%s", $1, $2, $3); for (i=4; i<=NF; i++) printf("\t%d", int($i)); }' |\
 # NOTE[shpynov] use awk instead of grep, because grep has some problems with tab characters.
 awk "/\t1\t0/" |\
 awk '{for (i=1; i<=3; i++) printf("%s%s", $i, (i==3) ? "\n" : "\t")}' |\
 sort -k1,1 -k2,2n -T ${TMP_DIR}

# Cleanup
rm ${SORTED1} ${SORTED2}
