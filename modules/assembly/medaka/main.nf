process MEDAKA {
    tag "Medaka consensus: ${sample_code}"
    label 'env_medaka'
    
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"
    
    input:
    tuple val(sample_code), path(trimmed_reads), path(final_polishing_fasta)

    output:
    path "medaka_output_${sample_code}"
    tuple val(sample_code), path("${sample_code}_consensus.fasta"), emit: assembly_medaka
    path "${task.process}.version.txt", emit: versions


    script:
    """
    set -euo pipefail

    echo -e "medaka\t\$(medaka_consensus 2>&1 | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -n 1)" > ${task.process}.version.txt

    echo "Using Medaka model: ${params.medaka_model}"
    
    mkdir -p medaka_output_${sample_code}

    medaka_consensus \
        -i ${trimmed_reads} \
        -d ${final_polishing_fasta} \
        -o medaka_output_${sample_code} \
        -t 2 \
        -m ${params.medaka_model}

    mv medaka_output_${sample_code}/consensus.fasta ${sample_code}_consensus.fasta
    """
}
