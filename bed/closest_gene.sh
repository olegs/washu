#!/usr/bin/env bash
# author: oleg.shpynov@jetbrains.com

# Check tool.
which bedtools &>/dev/null || { echo "ERROR: bedtools not found! Download bedTools: <http://code.google.com/p/bedtools/>"; exit 1; }

if [[ $# -lt 2 ]]; then
    echo "Need 2 parameters! <BED_FILE> <GENES.ANNOTATION.gtf | GENES.ANNOTATION.bed>"
    echo "Download annotation at: https://www.gencodegenes.org/"
    exit 1
fi
>&2 echo "closest_gene $@"

FILE=$1
GENES=$2

# Check configuration
[[ ! -z ${WASHU_ROOT} ]] || { echo "ERROR: WASHU_ROOT not configured"; exit 1; }
source ${WASHU_ROOT}/parallel/util.sh
export TMPDIR=$(type job_tmp_dir &>/dev/null && echo "$(job_tmp_dir)" || echo "/tmp")
mkdir -p "${TMPDIR}"

if [[ ! ${GENES} == *.bed ]]; then
    # Gtf to sorted tsv conversion
    GENES_TSV=${GENES/gtf/sorted.tsv}
    if [[ ! -f ${GENES_TSV} ]]; then
        >&2 echo "Converting gtf to ${GENES_TSV}"
        GENE_NAME_FIELD=$(cat ${GENES} | grep "chr1" | head -n 1 | awk '{for (i=1; i<NF; i++) {if ($i=="gene_name") print (i+1)}}')
        cat ${GENES} |  awk -v GN=${GENE_NAME_FIELD} 'OFS="\t" {if ($3=="gene") {print $1,$4-1,$5,$GN}}' | tr -d '";' |\
         sort -k1,1 -k2,2n -T ${TMPDIR} > ${GENES_TSV}
    fi
    GENES=${GENES_TSV}
fi

COLS=$(cat ${FILE} | grep "chr" | head -n 1 | awk '{ print NF }')
bedtools closest -a ${FILE} -b ${GENES} -d |\
    awk -v COLS=${COLS} '{out=$1; for (i=2;i<=COLS;i++) {out=out"\t"$i}; out=out"\t"$(COLS+4)"\t"$(COLS+5); print out; }'|\
    sort -k1,1 -k3,3n -k2,2n -T ${TMPDIR}

# TMP dir cleanup:
type clean_job_tmp_dir &>/dev/null && clean_job_tmp_dir
