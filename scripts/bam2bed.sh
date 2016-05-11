#!/usr/bin/env bash
# author oleg.shpynov@jetbrains.com

WORK_DIR=`pwd`
BAM_FILE=$1
NAME=${BAM_FILE%%.bam} # file name without extension

if [ ! -f "$NAME.bed" ]; then
    echo $(qsub << ENDINPUT
#!/bin/sh
#PBS -N bam2bed_$NAME
#PBS -l nodes=1:ppn=8,walltime=2:00:00,vmem=6gb
#PBS -j oe
#PBS -q dque
#PBS -o $WORK_DIR/qsub/bam2bed_$NAME.log

# Loading modules
module load bedtools

cd $WORK_DIR
bedtools bamtobed -i $BAM_FILE > $NAME.bed
ENDINPUT
)
fi