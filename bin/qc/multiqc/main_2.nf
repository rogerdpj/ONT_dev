process MULTIQC_FASTQ {
    tag "Generating MultiQC report"
    label 'env_multiqc_fastq'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.short_wgs.docker}" :
        params.short_wgs.docker }"

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