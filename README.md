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
    - [Parameters](#parameters)
- [References](#reference)



## Pipeline summary

All modes in the pipeline include the following steps:

1. **Long reads QC and trimming**: Assessment of read quality before and after filtering using [Nanoplot](https://github.com/wdecoster/NanoPlot) and summarised with [Nanocomp](https://github.com/wdecoster/nanocomp). Filtering of low-quality bases and short reads is performed using [Filtlong](https://github.com/rrwick/Filtlong) followed by removal of adapter ONT adapter sequences using [Porechop](https://github.com/rrwick/Porechop).

2. **Contaminant sequence removal**: [Kraken](https://github.com/DerrickWood/kraken) was used to classify non-bacterial reads and [SEQTK](https://github.com/lh3/seqtk) to filter out the reads flagged as contamimnats.

### mode --assemble

2. **Assembly**: *De novo* assembly using the single-molecule assembler [Flye](https://github.com/mikolmogorov/Flye) followed by multiple rounds of **polishing** and the construction of a consensus sequence using [Medaka](https://github.com/nanoporetech/medaka). 

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

2. **Assembly**: The [Autocycler](https://github.com/rrwick/Autocycler) tool is used to generate consensus *de novo* long-read assembly. The long-read assembly is then polished with the short Illumina reads following these steps:

    * <ins>Short reads QC and trimming</ins>: Assessment of short read quality before and after trimming using [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) and summarised with [MultiQC](https://github.com/MultiQC/MultiQC). Filtering of low-quality bases and short reads is performed with [Fastp](https://github.com/OpenGene/fastp).

    * <ins>Mapping and polishing</ins>: Short reads are mapped against the genome assembly using [bwa mem](https://github.com/lh3/bwa) followed by a filtering and polishing step to improve the genome assembly using [Polipolish](https://github.com/rrwick/Polypolish).

Once the consensus genome assemblies are obtained they are all processed the same way:

3. **Assembly and genome QC**:  Following genome assembly, structural quality metrics are evaluated with [QUAST](https://quast.sourceforge.net/), and genome completeness is assessed using [BUSCO](https://busco.ezlab.org/). A final report is generated with [MultiQC](https://github.com/MultiQC/MultiQC).

4. **Annotation**: Genome annotation is carried out with both [Prokka](https://github.com/tseemann/prokka) and [Bakta](https://github.com/oschwengers/bakta). The resulting gff annotation files are fixed and combine with [AGAT](https://github.com/NBISweden/AGAT).

4. **Post-assembly analyses**:
    *   Mass screening of contigs for antimicrobial resistance or virulence genes using [ABRIcate](https://github.com/tseemann/abricate).
    * Identification of antimicrobial resistance genes and point mutations in protein and/or assembled nucleotide sequences using [AMRFinder](https://github.com/ncbi/amr).
    * Scan genome against traditional PubMLST schemes using [MLST](https://github.com/tseemann/mlst). 


# Installation
The prerequisites to run the pipeline are:
- Install [Nextflow](https://github.com/nextflow-io/nextflow)
- Install [Docker](https://github.com/docker/docker-install) or [Singularity](https://github.com/sylabs/singularity-admindocs/blob/main/installation.rst) for container support
- Ensure [Java 8](https://github.com/winterbe/java8-tutorial) or higher is installed

Clone the Repository:

```
# Clone the workflow repository
git clone https://github.com/AMRmicrobiology/ONT_BACTERIAL_ANALYSIS.git

# Move inside the main directory
cd ONT_BACTERIAL_ANALYSIS
```
<!-- compl -->
### Local (conda)

  ```
  conda create -n Nanopore -f nanoporeWGS.yml busco.yml
  conda activate Nanopore
  ```
### Local (Singularity)
Remember to define the path for tmp files:

SINGULARITY_TMPDIR=/PATH/singularity/tmp
SINGULARITY_CACHEDIR=/PATH/singularity/cache
TMPDIR=/PATH/singularity/tmp

e.g:
```
SINGULARITY_TMPDIR=/mnt/dades/singularity/tmp
SINGULARITY_CACHEDIR=/mnt/dades/singularity/tmp
TMPDIR=/mnt/dades/singularity/tmp
export NFX_SINGULARITY_CACHEDIR =/mnt/dades/singularity/tmp

nextflow run main.nf --mode assemble --genome_size_file barcode_info.csv \
  --input '/PATH/TO/RUN/barcode*' \
  -w /PATH/WOR/DIRECTORY \
  -profile singularity 
  -resume

```


# How to use it?

Inside the ONT_BACTERIAL_ANALYSIS directory, modify the file  **genome_size.csv** to add for each barcode its expected genome size (bp) and the sample code you want to assign:

>[!IMPORTANT]
The sample code names should not include "-"

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
nextflow run main.nf --mode hybrid --genome_size_file barcode_info.csv --input '/path/to/data/barcode*' --short_inputs '/path/to/data/*_{1,2}.fastq.gz' -profile <docker/singularity/conda>
```

### Parameters

```bash
╭─ Required Options ──────────────────────────────────────────────────────────────────────────────────────────╮
│--mode             TEXT    Selection of the pipeline assemble/hybrid [required]                              │   
│--input            TEXT    Input barcode* folder(s) containing the long reads .fastq files [required]        │
│-profile           TEXT    Selection of execution profile (docker, singularity or conda) [required]          │
│--genome_size_file TEXT    Path to the .csv file with barcode, size and sample name information [required]   │  
│-profile           TEXT    Selection of execution profile (docker, singularity or conda) [required]          │
│                                                                                                             │
│  Pipeline specific                                                                                          │
│--short_inputs     TEXT    (--mode hybrid) Input FASTQ paired-end files (.fastq.gz format)  [required]       │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭─ Additional Options ────────────────────────────────────────────────────────────────────────────────────────╮
│--outdir           PATH    Directory to write the output [default: out]                                      │
│-w                 PATH    Path to the work dir. where temporary files will be written [default: ./work ]    │
│--organism         TEXT    To be used by Abricate. Abricate uses specific databases for Escherichia coli     │
│                           and Klebsiella pneumoniae [default: "" ]                                          │
│--help                     Show this message and exit                                                        │      
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
╭─ Long-read filtering Options ───────────────────────────────────────────────────────────────────────────────╮
│--min_length       INTEGER     Minimum length threshold (bp) [default: 1000]                                 │
│--min_mean_q       INTEGER     Minimum mean quality threshold [default: 10]                                  │
│--keep_percent     INTEGER     Throw out the worst (100-x)% of read bases [default: 90]                      │
╰─────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
```

## REFERENCE

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
