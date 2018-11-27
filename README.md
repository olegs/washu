License [![license](https://img.shields.io/github/license/mashape/apistatus.svg)](https://opensource.org/licenses/MIT)
Tests [![tests](http://teamcity.jetbrains.com/app/rest/builds/buildType:(id:Epigenome_Tools_Washu)/statusIcon.svg)](http://teamcity.jetbrains.com/viewType.html?buildTypeId=Epigenome_Tools_Washu&guest=1)
ChIP-Seq Pipeline tests [![long tests](http://teamcity.jetbrains.com/app/rest/builds/buildType:(id:Epigenome_Tools_WashuPipelineTests)/statusIcon.svg)](http://teamcity.jetbrains.com/viewType.html?buildTypeId=Epigenome_Tools_WashuPipelineTests&guest=1)  

Technical pipelines
===================
Technical pipelines for ChIP-Seq and RNA-Seq processing on Portable Batch System (`qsub`) or local machines.
ChIP-Seq pipeline were used for [Multiomics dissection of healthy human aging project](http://artyomovlab.wustl.edu/aging/index.html) ChIP-Seq data analysis.

How do I launch the ChIP-Seq pipeline?
--------------------------
Follow these instructions to launch ChIP-Seq pipeline:
* Configure environment, see **Requirements** section
* Place all the `.fastq` files to a single `<FASTQ_FOLDER>`
* Create `<INDEXES>` folder to store all the indexes required
* Launch the pipeline with desired `<genome>`, e.g. `mm9` or `hg19` 
```bash
python pipeline_chipseq.py <FASTQ_FOLDER> <INDEXES> <genome>
```

Requirements
------------
* Ensure you have Python 3 installed as default interpreter
* Add the following to `~/.bashrc` (Linux) or `~/.bash_profile` (MacOS):
```bash
# Configure project path
export WASHU_ROOT="<PATH_TO_REPOSITORY>"

# Configure correct python code execution
export PYTHONPATH="$WASHU_ROOT:$PYTHONPATH"

# Configure local machine parallelism
export WASHU_PARALLELISM=8
```

* Install required tools using [Conda](https://conda.io/docs/)
```bash
conda install --channel bioconda samtools bedtools bowtie bowtie2 fastqc multiqc sra-tools macs2 sicer \
    ucsc-bedgraphtobigwig ucsc-bedclip ucsc-bigwigaverageoverbed \
    star rseg 
```
For more details see `docker/biolabs/washu/Dockerfile`.
 * Download [Picard tools](https://github.com/broadinstitute/picard):
```bash 
curl --location https://github.com/broadinstitute/picard/releases/download/2.10.7/picard.jar \
    --output ~/picard.jar
```
* Download and extract [Phantompeakqualtools](https://github.com/kundajelab/phantompeakqualtools):
```bash
curl --location https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/phantompeakqualtools/ccQualityControl.v.1.1.tar.gz \
    --output ~/phantompeakqualtools.tar.gz 
tar xvf ~/phantompeakqualtools.tar.gz
```
* Download and extract [SPAN](https://artyomovlab.wustl.edu/aging/span.html):
```bash
curl --location https://download.jetbrains.com/biolabs/span/span-0.8.0.4533.jar \
    --output ~/span.jar 
```

Project
-------

* `/bed`            - BED files manipulations - intersection, ChromHMM enrichment, closes gene, etc.
* `/docker`         - Docker configuration files with tools and test data. See Tests section.
* `/downstream`     - Scripts for [Multiomics dissection of healthy human aging project](http://artyomovlab.wustl.edu/aging/index.html) ChIP-Seq data downstream analysis.
* `/parallel`       - Scripts for parallel execution of Portable Batch System (`qsub`) or on local machine.
* `/scripts`        - QC, Visualization, BAM conversions, Reads In Peaks, etc.
* `/test`           - Tests for pipelines.

Batch processing
---------------- 
All the scripts from `/parallel` are suitable to work with Portable Batch System and on local machine.
Parallelism level on local machine can be configured via **WASHU_PARALLELISM** environment variable.
 
Pipelines
---------
* `pipeline_chipseq.py` - Pipeline for batch ChIP-Seq processing, including QC, alignment, peak calling
* `pipeline_tf.py`      - Pipeline for batch Transcription Factor ChIP-Seq processing
* `pipeline_rnaseq.py`  - Pipeline for batch RNA-Seq processing, including QC, alignment, quantification

Tests
-----
For testing purposes we prepared a dedicated Docker image with all the tools and sample data.
Explore preconfigured Continuous Integration setup on [TeamCity](https://www.jetbrains.com/teamcity/?fromMenu):
* [ChIP-Seq Pipeline tests](http://teamcity.jetbrains.com/viewType.html?buildTypeId=Epigenome_Tools_WashuPipelineTests&guest=1)   
* [Other tests](http://teamcity.jetbrains.com/viewType.html?buildTypeId=Epigenome_Tools_Washu&guest=1)

Fetch latest Docker image `biolabs/washu` with all the necessary tools for pipeline and test data.
```bash
docker pull biolabs/washu
```

Or launch them locally:
```bash
# Change working directory
cd <project_path>

# Tests
docker run -v $(pwd):/washu -t -i biolabs/washu /bin/bash -c 
    "source activate py3.5 && cd /washu && bash test.sh"

# ChIP-Seq Pipeline tests
docker run -v $(pwd):/washu -t -m 2G -e JAVA_OPTIONS="-Xmx1G" -i biolabs/washu /bin/bash -c \
    "source activate py3.5 && cd /washu && bash test_pipeline_chipseq.sh"
```

Tools used
---------- 
[Bedtools](https://bedtools.readthedocs.io/en/latest/), 
[Bowtie](http://bowtie-bio.sourceforge.net/index.shtml), 
[Bowtie2](http://bowtie-bio.sourceforge.net/bowtie2/index.shtml), 
[ChIPDiff](https://academic.oup.com/bioinformatics/article/24/20/2344/258202/An-HMM-approach-to-genome-wide-identification-of),
[DiffBind](http://www.nature.com/nature/journal/v481/n7381/full/nature10730.html), 
[DiffReps](http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0065598),
[FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/),
[MACS2](https://github.com/taoliu/MACS),
[MANorm](https://www.ncbi.nlm.nih.gov/pubmed/22424423),
[MultiQC](http://multiqc.info/),
[Phantompeakqualtools](https://github.com/kundajelab/phantompeakqualtools),
[Picardtools](https://github.com/broadinstitute/picard),
[RSeg](https://academic.oup.com/bioinformatics/article/27/6/870/236489/Identifying-dispersed-epigenomic-domains-from-ChIP),
[Samtools](http://samtools.sourceforge.net/),
[SICER](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2732366/),
[SPAN](http://artyomovlab.wustl.edu/aging/span.html)

[STAR](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3530905/), 
[RSEM](https://bmcbioinformatics.biomedcentral.com/articles/10.1186/1471-2105-12-323)

Data standards and pipelines
--------------
* ENCODE data [standards](https://www.encodeproject.org/data-standards/)
* ENCODE ChIP-Seq [pipeline](https://github.com/ENCODE-DCC/chip-seq-pipeline)
* Blueprint ChIP-Seq [pipeline](http://dcc.blueprint-epigenome.eu/#/md/chip_seq_grch38)

Useful links
------------
* Washington University in Saint Louis Maxim Artyomov LAB [homepage](https://artyomovlab.wustl.edu/site/) 
* JetBrains Research BioLabs [homepage](https://research.jetbrains.org/groups/biolabs)
* Review on ChIP-Seq, ATAC-Seq and DNAse-Seq processing in latex [format](https://github.com/olegs/bioinformatics)