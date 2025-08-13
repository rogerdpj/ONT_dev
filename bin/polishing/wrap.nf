process WRAP {
    tag "Wrapping polished consensus for ${sample_code}"

    publishDir "${params.outdir}/2-assemble", mode: 'copy'

    container "$params.autocycler.docker"

    input:
    tuple val(sample_code), path(polished_fasta)  // direct from POLISH output

    output:
    tuple val(sample_code), path("${sample_code}_polished_rewrapped.fasta"), emit: polished_rewrapped

    script:
    """
    seqtk seq -l 60 ${polished_fasta} > ${sample_code}_polished_rewrapped.fasta
    """
}
