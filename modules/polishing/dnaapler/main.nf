process DNAAPLER {
    tag "Reorienting: ${sample_code}"
    label 'env_dnaapler'

    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"

    input:
    tuple val(sample_code), path(consensus_fasta)

    output:
    tuple val(sample_code), path("${sample_code}/${sample_code}_reoriented.fasta"), emit: reoriented_assembly
    path "${task.process}.version.txt", emit: versions

    script:

    """    
    set -euo pipefail

    echo -e "dnaapler\t\$(dnaapler --version 2>&1 | awk '{print \$3}')" > ${task.process}.version.txt
    
    dnaapler all \
        -i ${consensus_fasta} \
        -t ${task.cpus} \
        -o ${sample_code} \
        -p ${sample_code}
    """
}
