process WRAP {
    tag "Wrapping  ${sample_code}"
    label 'env_wrap'

    publishDir "${params.outdir}/2-Assembly", mode: 'copy', pattern: "*_final.fasta"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"

    input:
    tuple val(sample_code), path(fasta)

    output:
    tuple val(sample_code), path("${sample_code}_final.fasta"), emit: wrapped
    path "${task.process}.version.txt", emit: versions

    script:
    """
    set -euo pipefail

    echo -e "seqtk\t\$(seqtk 2>&1 | grep -i version || echo "seqtk version unknown")" > ${task.process}.version.txt

    seqtk seq -l 60 ${fasta} > ${sample_code}_final.fasta
    """
}
