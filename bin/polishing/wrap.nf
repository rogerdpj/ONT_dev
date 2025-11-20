process WRAP {
    tag "Wrapping polished consensus for ${sample_code}"
    label 'env_wrap'

    publishDir "${params.outdir}/2-Assembly", mode: 'copy'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.autocycler.docker}" :
        params.autocycler.docker }"

    input:
    tuple val(sample_code), path(polished_fasta)

    output:
    tuple val(sample_code), path("${sample_code}_polished_rewrapped.fasta"), emit: polished_rewrapped

    script:
    """
    seqtk seq -l 60 ${polished_fasta} > ${sample_code}_polished_rewrapped.fasta
    """
}
