# ONT_BACTERIAL_ANALYSIS

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![license-shield]][license-url]


## Introduction
This Nextflow pipeline provides an automated, reproducible and scalable solution for whole-genome sequencing (WGS) analysis in clinical microbiology research optimised for **Oxford Nanopore Technology (ONT)** data. It also supports **Illumina** data for *the novo* hybrid assemblies.

## Contents
- [Pipeline summary](#pipeline-summary)
    - [Assemble](#mode---assemble)
    - [Hybrid](#mode---hybrid)
- [Installation](#installation)
- [How to Use It](#how-to-use-it)
    - [Usage and Parameters](#usage-and-parameters)
- [Output](#output)
- [References](#references)



## Pipeline summary

All modes in the pipeline include the following steps:

1. **Long reads QC and trimming**: Assessment of read quality before and after filtering using [Nanoplot](https://github.com/wdecoster/NanoPlot). Filtering of low-quality bases and short reads is performed using [Filtlong](https://github.com/rrwick/Filtlong) followed by removal of ONT adapter sequences using [Porechop](https://github.com/rrwick/Porechop). All Nanoplot reports are summarised using [Nanocomp](https://github.com/wdecoster/nanocomp).

2. **Contaminant sequence removal**: The taxonomic sequence classifier [Kraken2](https://github.com/DerrickWood/kraken2) is used to identify contaminant non-bacterial reads followed by [SEQTK](https://github.com/lh3/seqtk) to filter out all reads flagged as contaminants.

From this point onwards two modes are available: If only ONT data is available **--mode assemble**; if both ONT and Illumina data are available, you should select **--mode hybrid** to perform a hybrid assembly.

### mode --assemble

2. **Assembly**: *De novo* assembly using the single-molecule assembler [Flye](https://github.com/mikolmogorov/Flye) followed by multiple rounds of **polishing** and the construction of a consensus sequence using [Medaka](https://github.com/nanoporetech/medaka). Genome assemblies are then reoriented using [dnaapler](https://github.com/gbouras13/dnaapler).

    * <ins>Polishing process</ins>: The optimal number of polishing rounds is determined automatically using the CART algorithm. The prediction is based on multiple parameters, which include error rate, N50/L50, genome coverage, Total Length of Matches, Average Occurrences, Distinct Minimizers, and processing time per round.

        <center>
        <table>
            <thead>
                <tr>
                    <th align= "center"> Source </th>
                    <th align= "center"> Parameter </th>
                    <th align= "center"> Description </th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td rowspan="4" align="center">Minimap2 </td>
                    <td align="center">DistinctMinimizers </td>
                    <td align="center">Number of unique minimizers found (Minimap2 value),change < 0.1% in distinct minimizers </td>
                </tr>
                <tr>
                    <td align="center">AverageOccurrences </td>
                    <td align="center">Average occurrences of minimizers (Minimap2),change < 0.01 in average occurrences </td>
                </tr>
                <tr>
                    <td align="center">TotalLengthMatches </td>
                    <td align="center">Total length of aligned matches,change < 0.1% </td>
                </tr>
                <tr>
                    <td align="center">ProcessingTime </td>
                    <td align="center">	Total execution time per round (Racon or Minimap2), change < 5%</td>
                </tr>
                <tr>
                    <td rowspan="1" align= "center"> RACON </td>
                    <td align= "center"> Processing Time </td>
                    <td align= "center"> Change < 5% </td>
                </tr>
                <tr>
                    <td rowspan="1" align= "center"> QUAST </td>
                    <td align= "center"> N50/L50 </td>
                    <td align= "center"> Minimum contig length that covers 50% of the assembly, change < 100 bp </td>
                </tr>
                <tr>
                    <td rowspan="1" align= "center"> QUAST/MEDAKA </td>
                    <td align="center"> ErrorRate </td>
                    <td align="center">	Error rate in the sequence after each polishing round </td>
                </tr>
                <tr>
                    <td rowspan="1" align= "center"> BUSCO </td>
                    <td align= "center"> Completeness (BUSCO) </td>
                    <td align ="center"> Change < 1% in complete genes </td>
                </tr>
                <tr>
                    <td rowspan=1 align= "center"> Target Value </td>
                    <td align= "center"> Optional Rounds </td>
                    <td align ="center"> Optimal number of rounds needed to achieve convergence </td>
                </tr>
            <t/body>
        </table>
        </center>

### mode --hybrid

2. **Assembly**: The [Autocycler](https://github.com/rrwick/Autocycler) tool is used to generate a consensus *de novo* long-read assembly by combining multiple alternative assemblies produced by different assemblers (e.g. Canu, Flye, NextDenovo, etc.). Afterwards, the consensus long-read genome is reoriented using [dnaapler](https://github.com/gbouras13/dnaapler) and then polished with the short Illumina reads following these steps:

    * <ins>Short reads QC and trimming</ins>: Trimming and filtering of low-quality bases and short reads are performed with [Fastp](https://github.com/OpenGene/fastp). Short read quality is assessed before and after trimming using [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/), and summarised using [MultiQC](https://github.com/MultiQC/MultiQC).

    * <ins>Mapping and polishing</ins>: Short reads are mapped to the consensus genome assembly using [BWA-MEM](https://github.com/lh3/bwa), followed by a filtering and polishing step to improve the assembly using [Polipolish](https://github.com/rrwick/Polypolish).

___________________________________
After the **consensus genome assemblies** have been generated, all assemblies are processed using the same workflow:

3. **Assembly and genome QC**:  Structural quality metrics are evaluated with [QUAST](https://quast.sourceforge.net/), and genome completeness is assessed using [BUSCO](https://busco.ezlab.org/). A final combined report is generated with [MultiQC](https://github.com/MultiQC/MultiQC).

4. **Annotation**: Genome annotation is performed using both [Prokka](https://github.com/tseemann/prokka) and [Bakta](https://github.com/oschwengers/bakta). The resulting GFF annotation files from both annotation tools are cleaned and combined using [AGAT](https://github.com/NBISweden/AGAT).

4. **Post-assembly analyses**:
    * Mass screening of contigs for antimicrobial resistance and virulence genes using [ABRIcate](https://github.com/tseemann/abricate).
    * Identification of antimicrobial resistance genes and point mutations in protein and/or assembled nucleotide sequences using [AMRFinder](https://github.com/ncbi/amr).
    * Screening of genomes against traditional PubMLST schemes using [MLST](https://github.com/tseemann/mlst).
    * Plasmid analysis: In case --plasmid option is added in the command line, the [mob-suite](https://github.com/phac-nml/mob-suite) tool is used to predict and identify the plasmid sequences from the assemblies. 


# Installation
Prerequisites to run the pipeline:
- Install [Nextflow](https://github.com/nextflow-io/nextflow) (Ver. ≥ 25.10.0).
- Install [Docker](https://github.com/docker/docker-install) or [Singularity](https://github.com/sylabs/singularity-admindocs/blob/main/installation.rst) for container support.
- Ensure that [Java 8](https://github.com/winterbe/java8-tutorial) or a more recent version is installed.

Clone the Repository:

```
# Clone the workflow repository
git clone https://github.com/AMRmicrobiology/ONT_BACTERIAL_ANALYSIS.git

# Move inside the main directory
cd ONT_BACTERIAL_ANALYSIS
```

#### Local (Singularity)
If you are running the pipeline locally, remember to define the path for Singularity temporary files and cache:
```
SINGULARITY_TMPDIR=/PATH/singularity/tmp
SINGULARITY_CACHEDIR=/PATH/singularity/cache
TMPDIR=/PATH/singularity/tmp
export NFX_SINGULARITY_CACHEDIR =/PATH/singularity/tmp
```
e.g:
```
SINGULARITY_TMPDIR=/mnt/dades/singularity/tmp
SINGULARITY_CACHEDIR=/mnt/dades/singularity/tmp
TMPDIR=/mnt/dades/singularity/tmp
export NFX_SINGULARITY_CACHEDIR=/mnt/dades/singularity/tmp

export APPTAINER_TMPDIR=/mnt/dades/singularity/tmp
export APPTAINER_CACHEDIR=/mnt/dades/singularity/cache
export APPTAINERENV_NXF_TASK_WORKDIR=/mnt/dades/singularity/tmp
export APPTAINERENV_TMPDIR=/mnt/dades/singularity/tmp
```
>[!NOTE]
Conda environments are listed and created but have not been tested.

# How to use it?

Inside the ONT_BACTERIAL_ANALYSIS directory, modify the file **barcode_info.csv** to add the expected genome size (bp) and sample code you want to assign to each barcode:

>[!IMPORTANT]
The sample code names should not include "-".

e.g.
```
barcode,genome_size,sample_code
barcode01,3000000,306 
barcode02,4500000,C2_72
barcode03,5000000,C2_75
barcode04,4000000,C2_76
barcode05,3200000,ST89
barcode06,3500000,ST23
```
Run the pipeline using the following command, adjusting the parameters as needed:

*ASSEMBLE*
```
nextflow run main.nf --mode assemble --genome_size_file barcode_info.csv --input '/path/to/data/barcode*' -profile <docker/singularity/conda>
```

*HYBRID*
```
nextflow run main.nf --mode hybrid --genome_size_file barcode_info.csv --input '/path/to/data/barcode*' --short_reads '/path/to/data/*_{1,2}.fastq.gz' -profile <docker/singularity/conda>
```

### Usage and parameters

```bash
Usage: nextflow run main.nf [--help] [--mode VAR] [--genome_size_file VAR] [--input VAR] [--short_reads VAR] [--outdir VAR] [--organism VAR] [--min_length VAR] [--min_mean_q VAR] [--keep_percent VAR] [--plasmid] [--bakta_db_define VAR] [--db_select VAR] [--abricate_db VAR] [-w VAR] [-profile VAR]
  
Input data arguments
  --mode             TEXT        Selection of the pipeline assemble/hybrid [required]
  --input            PATH        Input barcode* folder(s) containing the long reads .fastq.gz files [required]
  --genome_size_file PATH        Path to the .csv file with barcode, size and sample name information [required]
  Pipeline specific
  --short_reads     PATH        (--mode hybrid) Input FASTQ paired-end files named *_{1,2} (.fastq.gz format) [required]
  
Nextflow arguments
  -profile           TEXT        Selection of execution profile (docker, singularity or conda) [required]
  -w                 PATH        Path to the work dir. where temporary files will be written [default: ./work ]
  
Output arguments
  --outdir           PATH        Directory to write the output [default: ./out]
  
Optional arguments 
  --help                         Show this message and exit      
  --plasmid          BOOLEAN     Add this parameter to identify and type plasmid sequences in your assembly [default: false]
  
Long-read filtering arguments
  --min_length       INTEGER     Minimum length threshold (bp) [default: 1000]
  --min_mean_q       INTEGER     Minimum mean quality threshold [default: 10]
  --keep_percent     INTEGER     Throw out the worst (100-x)% of read bases [default: 90].
  
AMR arguments
  --organism         TEXT        By default, ABRicate searches the following databases: vfdb_full, resfinder, plasmidfinder, and card. If Escherichia coli or Klebsiella pneumoniae is specified, ecoli_vf and argannot will be searched, respectively, instead of vfdb_full [default: ""]. 
  
Databases arguments
  --bakta_db_define  PATH        Define the path to the user downloaded database to be used by Bakta. By default the database is downloaded if no argument is added. Another option is to copy-paste the database directly to the "./bakta_db" directory
  --db_select        TEXT/PATH   Kraken2 database to use for taxonomy classification. The options "db_16GB" or "db_full_60GB" are downloaded automatically if specified. Alternatively, a path to a user-provided database may be supplied. Another option is to copy-paste the database directly into the "./kraken_db" directory [default: "db_16GB"]
  --abricate_db      PATH        Path to the user downloaded databases to be used by Abricate

```
## Output
This is the forder architecture and the content of the output data directory:

<div style="overflow-x: auto;">

<table>
    <thead>
        <tr>
            <th align="center">Folder</th>
            <th align="center">Subfolder</th>
            <th align="center">Description</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td rowspan="2" align="center"><nobr>1-QC</td>
            <td align="center"><nobr>data_QC</td>
            <td align="center">Individual initial Nanoplot results folders and Nanocomp summary of all reports before and after trimming</td>
        </tr>
        <tr>
            <td align="center"><nobr>genome_QC</td>
            <td align="center">Individual BUSCO and QUAST reports folders and MultiQC combined report of all samples</td>
        </tr>
        <tr>
            <td rowspan="4" align="center"><nobr>2-Assembly</td>
            <td align="center"></td>
            <td align="center">All final consensus genomes assemblies ("sample_ID"_consensus_wrapped.fasta)</td>
        </tr>
        <tr>
            <td align="center"><nobr>1-Fly_structural</td>
            <td align="center">Nanostats results and Flye output results directories containing the graph files</td>
        </tr>
        <tr>
            <td align="center"><nobr>2-Medaka_results</td>
            <td align="center">Medaka output directories</td>
        </tr>
        <tr>
            <td align="center"><nobr>3-Annotations</td>
            <td align="center">All combined files produced by AGAT from Bakta and Prokka annotation tools are located here. Also, Bakta and Prokka output directories</td>
        </tr>
        <tr>
            <td rowspan="2" align="center"><nobr>3-AMR</td>
            <td align="center">ABRICATE</td>
            <td align="center">ABRICATE search results</td>
        </tr>
        <tr>
            <td align="center">AMRFinder</td>
            <td align="center">AMRFinder search results</td>
        </tr>
        <tr>
            <td align="center"><nobr>4-MLST</td>
            <td align="center"></td>
            <td align="center">MLST results</td>
        </tr>
        <tr>
            <td align="center"><nobr>5-Plasmids</td>
            <td align="center"></td>
            <td align="center">MOB-suite plasmid tool output directories</td>
        </tr>
    </tbody>
</table>

</div>


## References

[Benchmarking reveals superiority of deep learning variant callers on bacterial Nanopore sequence data](https://elifesciences.org/articles/98300)
[How low can you go? Short-read polishing of Oxford Nanopore bacterial genome assemblies](https://www.microbiologyresearch.org/content/journal/mgen/10.1099/mgen.0.001254)

[Evaluation of the accuracy of bacterial genome reconstruction with Oxford Nanopore R10.4.1 long-read-only sequencing](https://www.microbiologyresearch.org/content/journal/mgen/10.1099/mgen.0.001246)

[Assembling the perfect bacterial genome using Oxford Nanopore and Illumina sequencing](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1010905)

[Autocylcler](https://github.com/rrwick/Autocycler)



[contributors-shield]: https://img.shields.io/github/contributors/jimmlucas/DIvergenceTimes.svg?style=for-the-badge
[contributors-url]: https://github.com/jimmlucas/DIvergenceTimes/graphs/contributors

[forks-shield]: https://img.shields.io/github/forks/jimmlucas/DIvergenceTimes.svg?style=for-the-badge
[forks-url]: https://github.com/jimmlucas/DIvergenceTimes/network/members

[stars-shield]: https://img.shields.io/github/stars/jimmlucas/DIvergenceTimes.svg?style=for-the-badge
[stars-url]: https://github.com/gjimmlucas/DIvergenceTimes/stargazers

[issues-shield]: https://img.shields.io/github/issues/jimmlucas/DIvergenceTimes.svg?style=for-the-badge
[issues-url]: https://github.com/jimmlucas/DIvergenceTimes/issues

[license-shield]: https://img.shields.io/github/license/jimmlucas/DIvergenceTimes.svg?style=for-the-badge
[license-url]: https://github.com/jimmlucas/DIvergenceTimes/blob/master/LICENSE.txt
