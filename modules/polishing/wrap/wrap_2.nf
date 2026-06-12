process WRAP {
    tag "Wrapping polished consensus for ${sample_code}"
    label 'env_wrap'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.autocycler.docker}" :
        params.autocycler.docker }"


    publishDir "${params.outdir}/2-Assembly", mode: 'copy'
    
    input:
    tuple val(sample_code), path(medaka_fasta) 

    output:
    tuple val(sample_code), path("${sample_code}_consensus_wrapped.fasta"), emit: wrapped

    script:
    """
    seqtk seq -l 60 ${medaka_fasta} > ${sample_code}_consensus_wrapped.fasta
    """
}
