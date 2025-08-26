process MULTIQC_FASTQ {

    tag "Generating MultiQC report"

    container "$params.quast.docker"

    publishDir "${params.outdir}/1-QC/data_QC", mode: 'copy'

    input:
    path fastqc_first
    path fastqc_after

    output:
    path "Illumina_multiqc_report"

    script:
    """
    echo "FastQC files: ${fastqc_first} ${fastqc_after}"

    multiqc ${fastqc_first} ${fastqc_after} -o Illumina_multiqc_report
    """
}