process BAKTA {
    tag "BAKTA annotation: ${sample_code}"
    label 'env_bakta' 

    publishDir "${params.outdir}/2-Assembly/2-Annotations", mode: 'copy', pattern: "annotations_${sample_code}/*"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"

    input:
    tuple val(sample_code), path(assembly_file)

    output:
    tuple val(sample_code), path("annotations_${sample_code}/${sample_code}.gff3"), emit: bakta_gff3
    path "annotations_${sample_code}/*", emit: bakta_results
    path "${task.process}.version.txt", emit: versions

    script:
    """ 
    set -euo pipefail

    export MPLCONFIGDIR="\$PWD/.mplconfig"
    mkdir -p "\$MPLCONFIGDIR"
    
    echo -e "bakta\t\$(bakta --version 2>&1 | grep -i bakta | head -n 1 | awk '{print \$2}')" > ${task.process}.version.txt

    bakta \
          --threads 4 \
          --keep-contig-headers \
          --skip-sorf \
          --prefix ${sample_code} \
          --output annotations_${sample_code} \
          ${assembly_file}

    """
}
