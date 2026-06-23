process AMR_2 {
    tag "AMRFinder: ${sample_code}"
    label 'env_amrfinder'
        
    publishDir "${params.outdir}/3-AMR/AMRFinder", mode: 'copy', pattern: "*.tsv"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"

    input:
    tuple val(sample_code), path(assembly_file)

    output:
    path("${sample_code}_amrfinder_report.tsv"), emit: amrfinder_report
    tuple val(sample_code), path("${sample_code}_amrfinder_report.tsv"), emit: amrfinder_tuple 
    path "${task.process}.version.txt", emit: versions

    script:
    """
    set -euo pipefail

    echo -e "amrfinder\t\$(amrfinder --version 2>&1 | head -n 1)" > ${task.process}.version.txt

    amrfinder \
        -n ${assembly_file} \
        -o ${sample_code}_amrfinder_report.tsv
    """
}