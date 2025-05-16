process MULTIQC {

    tag "Generating MultiQC report"
    
    container "$params.quast.docker"
    
    publishDir "${params.outdir}/1-QC/genomeQC", mode: 'copy'

    input:
    path (quast_folder)
    path (busco_folder)

    output:
    path "multiqc_report"

    script:

    """
    multiqc ./ -o multiqc_report

    """
}