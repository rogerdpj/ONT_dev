process BUSCO {
    tag "BUSCO for ${sample_code}"
    label 'env_busco'

    publishDir "${params.outdir}/1-QC/genome_QC/1-BUSCO", mode: "copy", pattern: "${sample_code}_busco*"
    publishDir "${params.outdir}/versions", mode: "copy", pattern: "*.version.txt"


    input:
    tuple val(sample_code), path(assemble)

    output:
    tuple val(sample_code), path("${sample_code}_busco"), emit: results
    path "${task.process}.version.txt", emit: versions

    script:

    """
    set -euo pipefail

    echo -e "busco\t\$(busco --version 2>&1)" > ${task.process}.version.txt

    busco \
        -i ${assemble} \
        -m genome \
        -l ${params.busco_lineage} \
        -o ${sample_code}_busco \
        -c ${task.cpus} 
    """
}
