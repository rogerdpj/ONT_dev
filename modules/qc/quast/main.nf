process QUAST {
    tag "QUAST: ${sample_code}"
    label 'env_quast'

    publishDir "${params.outdir}/1-QC/genome_QC/2-QUAST", mode: 'copy', pattern: "quast_result_${sample_code}*"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"

    input:
    tuple val(sample_code), path(consensus)

    output:
    tuple val(sample_code), path("quast_result_${sample_code}"), emit: results
    path "${task.process}.version.txt", emit: versions

    script:

    """
    echo -e "quast\t\$(quast.py --version 2>&1 | grep -i 'QUAST' | awk '{print \$2}')" > ${task.process}.version.txt
    
    mkdir -p quast_result_${sample_code}

    if [ -s ${consensus} ]; then
        quast.py -t ${task.cpus} --min-contig 500 -o quast_result_${sample_code} ${consensus} \
        || echo "QUAST failed for ${sample_code}" > quast_result_${sample_code}/quast_error.log
    else
        echo "Skipping QUAST for ${sample_code} due to missing or empty consensus file." > quast_result_${sample_code}/quast_error.log
    fi
    """
}