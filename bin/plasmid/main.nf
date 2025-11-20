process PLASMID_SEARCH {

    tag "Plasmid typing for ${sample_code}}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.mob_suit.docker}" :
        params.mob_suit.docker }"

    publishDir "${params.outdir}/5-Plasmids", mode: 'copy'

    input:
    tuple val(sample_code), path(consensus_fasta)

    output:
    tuple val(sample_code),  path("${sample_code}_mob_output"), emit: mob_result

    script:
    """
    mkdir -p ${sample_code}_mob_output
    mob_recon \\
      -i ${consensus_fasta} \\
      -o ${sample_code}_mob_output \\
      --force \\
      -n 8 \\
      -c \\
      --min_rep_cov 40 \\
      --min_mob_cov 40 \\
      --min_con_cov 40
    """
}