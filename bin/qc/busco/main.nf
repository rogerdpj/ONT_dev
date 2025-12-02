process BUSCO {
    tag "GENOME COMPLETENESS"
    label 'env_busco'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.busco.docker}" :
        params.busco.docker }"

    publishDir "${params.outdir}/1-QC/genome_QC/BUSCO", mode: "copy" 

    input:
    tuple val(sample_code), path(assemble)

    output:
    tuple val(sample_code), path("${sample_code}_busco")

    script:

    """
    busco -i ${assemble} -m genome -l bacteria -o ${sample_code}_busco
    """
}
