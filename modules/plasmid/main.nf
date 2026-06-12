process PLASMID_SEARCH {
    tag "Plasmid typing for ${sample_code}"
    label 'env_plasmid'

    publishDir "${params.outdir}/5-Plasmids", mode: 'copy', pattern: "*_mob_output*"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"

    input:
    tuple val(sample_code), path(consensus_fasta)

    output:
    tuple val(sample_code),  path("${sample_code}_mob_output"), emit: mob_result
    path "${task.process}.version.txt", emit: versions

    script:
    """
    set -euo pipefail

    echo -e "mob_suite\t\$(mob_recon --version 2>&1 | head -n 1)" > ${task.process}.version.txt

    mkdir -p ${sample_code}_mob_output

    mob_recon \
      -i ${consensus_fasta} \
      -o ${sample_code}_mob_output \
      --force \
      -n ${task.cpus} \
      -c \
      --min_rep_cov 40 \
      --min_mob_cov 40 \
      --min_con_cov 40
    """
}