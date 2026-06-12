process MLST {
    tag "MLST for ${sample_code}"
    label 'env_mlst'
    
    publishDir "${params.outdir}/4-MLST", mode: 'copy', pattern: "*.mlst.tab"
    publishDir "${params.outdir}/4-MLST", mode: 'copy', pattern: "*.mlst.json"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"

    input:
    tuple val(sample_code), path(assembly_file)

    output:
    path("*.mlst.tab"), emit: tab
    path("*.mlst.json"), emit: json
    path "${task.process}.version.txt", emit: versions

    script:
    """
    set -euo pipefail

    echo -e "mlst\t\$(mlst --version 2>&1 | head -n 1)" > ${task.process}.version.txt

    mlst \
        --threads ${task.cpus} \
        --json ${sample_code}.mlst.json \
        ${assembly_file} > ${sample_code}.mlst.tab
    """
}
