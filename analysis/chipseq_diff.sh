#!/usr/bin/env bash
# Script to process differential chip-seq analysis
# author Oleg Shpynov (oleg.shpynov@jetbrains.com)

# Check tools
which bedtools &>/dev/null || { echo "bedtools not found! Download bedTools: <http://code.google.com/p/bedtools/>"; exit 1; }
which macs2 &>/dev/null || { echo "macs2 not found! Install macs2: <https://github.com/taoliu/MACS/wiki/Install-macs2>"; exit 1; }

# Load cluster stuff
source ~/work/washu/scripts/util.sh

################################################################################
# Configuration start ##########################################################
################################################################################

GROUP1="Y"
echo "GROUP1"
echo $GROUP1

GROUP2="O"
echo "GROUP2"
echo $GROUP2

# Configure folder
BASE="/scratch/artyomov_lab_aging/Y10OD10"
if [ ! -d $BASE ]; then
    BASE="/mnt/stripe/bio/raw-data/aging/Y10OD10"
fi
if [ ! -d $BASE ]; then
    BASE="/Volumes/WD/scratch/artyomov_lab_aging/Y10OD10"
fi
FOLDER="$BASE/chipseq/processed/3vs3_2"
echo "FOLDER"
echo $FOLDER

CHROM_SIZES="$BASE/../indexes/hg19/hg19.chrom.sizes"
echo "CHROM_SIZES"
echo $CHROM_SIZES

NAME="diff_k27ac_${GROUP1}_${GROUP2}"
echo "NAME"
echo $NAME

PREFIX="$(pwd)/$NAME"
echo "PREFIX"
echo $PREFIX

# Base Q value threshold for all the experiments
Q=0.01
echo "Q"
echo $Q

READS1=$(find ${FOLDER}/k27ac_bams -name 'YD_ac*.bam' | tr '\n' ' ') # Replace all newlines with spaces
echo "READS $GROUP1"
echo $READS1
READS2=$(find ${FOLDER}/k27ac_bams -name 'OD_ac*.bam' | tr '\n' ' ')
echo "READS $GROUP2"
echo $READS2

INPUTS1=$(find ${FOLDER}/k27ac_bams -name 'YD_input.bam' | tr '\n' ' ')
echo "INPUT_READS $GROUP1"
echo $INPUTS1
INPUTS2=$(find ${FOLDER}/k27ac_bams -name 'OD_input.bam' | tr '\n' ' ')
echo "INPUT_READS $GROUP2"
echo $INPUTS2

PEAKS1=$(find ${FOLDER}/k27ac_bams_macs_broad_${Q} -name 'YD_ac*.broadPeak' | tr '\n' ' ')
echo "INDIVIDUAL_PEAKS $GROUP1"
echo $PEAKS1
PEAKS2=$(find ${FOLDER}/k27ac_bams_macs_broad_${Q} -name 'OD_ac*.broadPeak' | tr '\n' ' ')
echo "INDIVIDUAL_PEAKS $GROUP2"
echo $PEAKS2


################################################################################
# Configuration end ############################################################
################################################################################

DIFF_MACS_POOLED="${PREFIX}_macs_pooled"
echo
echo "Processing $DIFF_MACS_POOLED"
if [ ! -d $DIFF_MACS_POOLED ]; then
    mkdir ${DIFF_MACS_POOLED}
    cd ${DIFF_MACS_POOLED}
    echo "Processing MACS2 pooled peaks and compare them";

    QSUB_ID1=$(qsub << ENDINPUT
#!/bin/sh
#PBS -N ${NAME}_1_macs2_broad_${Q}
#PBS -l nodes=1:ppn=8,walltime=24:00:00,vmem=16gb
#PBS -j oe
#PBS -o ${DIFF_MACS_POOLED}/${NAME}_1_macs2_broad_${Q}.log
# This is necessary because qsub default working dir is user home
cd ${DIFF_MACS_POOLED}
macs2 callpeak -t $READS1 -c $INPUTS1 -f BAM -g hs -n ${GROUP1}_${Q} -B --broad --broad-cutoff ${Q}
ENDINPUT
)

    QSUB_ID2=$(qsub << ENDINPUT
#!/bin/sh
#PBS -N ${NAME}_2_macs2_broad_${Q}
#PBS -l nodes=1:ppn=8,walltime=24:00:00,vmem=16gb
#PBS -j oe
#PBS -o ${DIFF_MACS_POOLED}/${NAME}_2_macs2_broad_${Q}.log
# This is necessary because qsub default working dir is user home
cd ${DIFF_MACS_POOLED}
macs2 callpeak -t $READS2 -c $INPUTS2 -f BAM -g hs -n ${GROUP2}_${Q} -B --broad --broad-cutoff ${Q}
ENDINPUT
)
    wait_complete "$QSUB_ID1 $QSUB_ID2"
    check_logs
    bash ~/work/washu/bed/compare.sh ${GROUP1}_${Q}_peaks.broadPeak ${GROUP2}_${Q}_peaks.broadPeak ${NAME}_${Q}
fi


DIFF_MACS_POOLED_1_VS_2="${PREFIX}_macs_pooled_1_vs_2"
echo
echo "Processing $DIFF_MACS_POOLED_1_VS_2"
if [ ! -d $DIFF_MACS_POOLED_1_VS_2 ]; then
    mkdir ${DIFF_MACS_POOLED_1_VS_2}
    cd ${DIFF_MACS_POOLED_1_VS_2}

    echo "Processing MACS2 pooled ${GROUP1} vs ${GROUP2} as control and vice versa"
    
    QSUB_ID_1_2=$(qsub << ENDINPUT
#!/bin/sh
#PBS -N ${NAME}_1_vs_2_macs2_broad
#PBS -l nodes=1:ppn=8,walltime=24:00:00,vmem=16gb
#PBS -j oe
#PBS -o ${DIFF_MACS_POOLED_1_VS_2}/${NAME}_1_vs_2_macs2_broad.log
# This is necessary because qsub default working dir is user home
cd ${DIFF_MACS_POOLED_1_VS_2}
macs2 callpeak -t $READS1 -c $READS2 -f BAM -g hs -n ${NAME}_1_vs_2_${Q} -B --broad --broad-cutoff ${Q}
ENDINPUT
)
    QSUB_ID_2_1=$(qsub << ENDINPUT
#!/bin/sh
#PBS -N ${NAME}_2_vs_1_macs2_broad
#PBS -l nodes=1:ppn=8,walltime=24:00:00,vmem=16gb
#PBS -j oe
#PBS -o ${DIFF_MACS_POOLED_1_VS_2}/${NAME}_2_vs_1_macs2_broad.log
# This is necessary because qsub default working dir is user home
cd ${DIFF_MACS_POOLED_1_VS_2}
macs2 callpeak -t $READS2 -c $READS1 -f BAM -g hs -n ${NAME}_2_vs_1_${Q} -B --broad --broad-cutoff ${Q}
ENDINPUT
)
    wait_complete "$QSUB_ID_1_2 $QSUB_ID_2_1"
    check_logs
fi

macs2_total_tags_control() {
    echo $(cat $1 | grep "total tags in control" | sed 's/.*total tags in control: //g')
}

DIFF_MACS_BDGDIFF="${PREFIX}_macs_bdgdiff"
echo
echo "Processing $DIFF_MACS_BDGDIFF"
if [ ! -d $DIFF_MACS_BDGDIFF ]; then
    mkdir ${DIFF_MACS_BDGDIFF}
    cd ${DIFF_MACS_BDGDIFF}

    echo "Use MACS2 pooled peaks as input for MACS2 bdgdiff"

    CONTROL1=$(macs2_total_tags_control ${DIFF_MACS_POOLED}/${GROUP1}_${Q}_peaks.xls)
    echo "Control $GROUP1: $CONTROL1"
    CONTROL2=$(macs2_total_tags_control ${DIFF_MACS_POOLED}/${GROUP2}_${Q}_peaks.xls)
    echo "Control $GROUP2: $CONTROL2"

    QSUB_ID=$(qsub << ENDINPUT
#!/bin/sh
#PBS -N ${NAME}_macs2_broad_bdgdiff
#PBS -l nodes=1:ppn=8,walltime=24:00:00,vmem=16gb
#PBS -j oe
#PBS -o ${DIFF_MACS_BDGDIFF}/${NAME}_macs2_broad_bdgdiff.log
# This is necessary because qsub default working dir is user home
cd ${DIFF_MACS_BDGDIFF}
macs2 bdgdiff\
 --t1 ${DIFF_MACS_POOLED}/${GROUP1}_${Q}_treat_pileup.bdg --c1 ${DIFF_MACS_POOLED}/${GROUP1}_${Q}_control_lambda.bdg\
 --t2 ${DIFF_MACS_POOLED}/${GROUP2}_${Q}_treat_pileup.bdg --c2 ${DIFF_MACS_POOLED}/${GROUP2}_${Q}_control_lambda.bdg\
  --d1 ${CONTROL1} --d2 ${CONTROL2} --o-prefix ${NAME}_${Q}
ENDINPUT
)
    wait_complete "$QSUB_ID"
    check_logs
fi


bams_to_tags() {
    OUT=$1
    # Shift arguments
    shift 1
    for F in $@; do
        >&2 echo $F
        bedtools bamtobed -i ${F} | grep -E "chr[0-9]+|chrX" | awk '{print $1, $2, $6}' >> $OUT
    done
}

# Pooled ChIPDiff
CHIPDIFF="${PREFIX}_chipdiff"
echo
echo "Processing $CHIPDIFF"
if [ ! -d $CHIPDIFF ]; then
    mkdir ${CHIPDIFF}
    cd ${CHIPDIFF}
    echo "Processing chipdiff as on pooled tags (reads)"

    cat >config.txt <<CONFIG
maxIterationNum  500
minP             0.95
maxTrainingSeqNum 10000
minFoldChange    3
minRegionDist    1000
CONFIG
    >&2 echo "Processing ${GROUP1} Tags";
    bams_to_tags ${GROUP1}_tags.tag $READS1

    >&2 echo "Processing ${GROUP2} Tags";
    bams_to_tags ${GROUP2}_tags.tag $READS2

    QSUB_ID=$(qsub << ENDINPUT
#!/bin/sh
#PBS -N ${NAME}_chipdiff_3
#PBS -l nodes=1:ppn=8,walltime=24:00:00,vmem=16gb
#PBS -j oe
#PBS -o ${CHIPDIFF}/${NAME}_chipdiff_3.log
# This is necessary because qsub default working dir is user home
cd ${CHIPDIFF}

sort -k1,1 -k2,2n -o ${GROUP1}_tags_sorted.tag ${GROUP1}_tags.tag
sort -k1,1 -k2,2n -o ${GROUP2}_tags_sorted.tag ${GROUP2}_tags.tag

ChIPDiff ${GROUP1}_tags_sorted.tag ${GROUP2}_tags_sorted.tag $CHROM_SIZES config.txt ${NAME}_3
cat ${NAME}_3.region | awk -v OFS='\t' '$4=="-" {print $1,$2,$3}' > ${NAME}_3_cond1.bed
cat ${NAME}_3.region | awk -v OFS='\t' '$4=="+" {print $1,$2,$3}' < ${NAME}_3_cond2.bed
ENDINPUT
)
    wait_complete "$QSUB_ID"
    check_logs
fi


bams_to_reads() {
    OUT=$1
    # Shift arguments
    shift 1
    for F in $@; do
        >&2 echo $F
        bedtools bamtobed -i ${F} | grep -E "chr[0-9]+|chrX" | awk '{print $1, $2, $3, $6}' >> $OUT
    done
}

macs2_shift() {
    echo $(cat $1 | grep "# d =" | sed 's/.*# d = //g')
}

# MANorm
MANORM="${PREFIX}_manorm"
echo
echo "Processing $MANORM"
if [ ! -d $MANORM ]; then
    mkdir ${MANORM}
    mkdir ${MANORM}/${Q}
    cd ${MANORM}/${Q}

    echo "Processing MAnorm using pooled MACS2 peaks as peakfile and pooled reads as readfiles"
# README.txt
# Create a folder and place in the folder MAnorm.sh, MAnorm.r, and all 4 bed files to be analyzed.
# run command:   ./MAnorm.sh    sample1_peakfile[BED]     sample2_peakfile[BED] \
#                               sample1_readfile[BED]     sample2_readfile[BED]  \
#                               sample1_readshift_lentgh[INT]      sample2_readshift_length[INT]
    MANORM_SH=$(which MAnorm.sh)
    echo "Found MAnorm.sh: ${MANORM_SH}"
    cp ${MANORM_SH} ${MANORM_SH%%.sh}.r ${MANORM}/${Q}

    cp ${DIFF_MACS_POOLED}/${GROUP1}_${Q}_peaks.broadPeak ${MANORM}/${Q}/${GROUP1}_peaks.bed
    cp ${DIFF_MACS_POOLED}/${GROUP2}_${Q}_peaks.broadPeak ${MANORM}/${Q}/${GROUP2}_peaks.bed

    >&2 echo "Processing ${GROUP1} Pooled Reads";
    bams_to_reads ${GROUP1}_reads.bed $READS1
    >&2 echo "Processing ${GROUP2} Pooled Reads";
    bams_to_reads ${GROUP2}_reads.bed $READS2

    # Check MACS2 for shift values
    SHIFT1=$(macs2_shift ${DIFF_MACS_POOLED}/${GROUP1}_${Q}_peaks.xls)
    echo "SHIFT ${GROUP1}: $SHIFT1"
    SHIFT2=$(macs2_shift ${DIFF_MACS_POOLED}/${GROUP2}_${Q}_peaks.xls)
    echo "SHIFT ${GROUP2}: $SHIFT2"

    QSUB_ID=$(qsub << ENDINPUT
#!/bin/sh
#PBS -N manorm_k27ac
#PBS -l nodes=1:ppn=8,walltime=24:00:00,vmem=16gb
#PBS -j oe
#PBS -o ${MANORM}/${Q}/manorm_k27ac_3.log
# This is necessary because qsub default working dir is user home
cd ${MANORM}/${Q}

sort -k1,1 -k2,2n -o ${GROUP1}_reads_sorted.bed ${GROUP1}_reads.bed
sort -k1,1 -k2,2n -o ${GROUP2}_reads_sorted.bed ${GROUP2}_reads.bed

sort -k1,1 -k2,2n -o ${GROUP1}_peaks_sorted.bed ${GROUP1}_peaks.bed
sort -k1,1 -k2,2n -o ${GROUP2}_peaks_sorted.bed ${GROUP2}_peaks.bed

# Load required modules
module load R
module load bedtools2

bash ${MANORM}/${Q}/MAnorm.sh ${GROUP1}_peaks_sorted.bed ${GROUP2}_peaks_sorted.bed \
${GROUP1}_reads_sorted.bed ${GROUP2}_reads_sorted.bed $SHIFT1 $SHIFT2
ENDINPUT
)
    wait_complete "$QSUB_ID"
    check_logs
fi