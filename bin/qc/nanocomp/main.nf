process NANOCOMP {
    tag "Nanocomp process"
    label 'env_nanocomp'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.long_read.docker}" :
        params.long_read.docker }"
    
    publishDir "${params.outdir}/1-QC/data_QC", mode: 'copy'

    input:
    path (barcode_dir)
    path (barcode_id_clean)

    output:

    path "Nanocomp"

    script:

    """
    source activate nanopore    
    NanoComp --fastq ${barcode_dir} ${barcode_id_clean} -o Nanocomp
    
    """
}
