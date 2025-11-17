process WRAP {
    tag "Wrapping polished consensus for ${sample_code}"

    publishDir "${params.outdir}/2-Assembly", mode: 'copy'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.autocycler.docker}" :
        params.autocycler.docker }"

    input:
    tuple val(sample_code), path(medaka_fasta) 

    output:
    tuple val(sample_code), path("${sample_code}_consensus_wrapped.fasta"), emit: wrapped

    script:
    """
    seqtk seq -l 60 ${medaka_fasta} > ${sample_code}_consensus_wrapped.fasta
    """
}
