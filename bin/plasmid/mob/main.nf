process MOB_SUITE {

    tag "MOB-suite on ${barcode_id}"

    publishDir "${params.outdir}/12-mob_recon", mode: 'copy'

    container "$params.mob_suit.docker"

    input:
    tuple val(sample_code), val(barcode_id), path(plasmid_fasta)

    output:
    tuple val(sample_code), val(barcode_id), path("${barcode_id}_mob_output"), emit: mob_result

    script:
    """
    mkdir -p ${barcode_id}_mob_output

    mob_recon \\
      -i ${plasmid_fasta} \\
      -o ${barcode_id}_mob_output \\
      --force \\
      -n 8 \\
      -t \\
      -c \\
      --min_length 1000 \\
      --min_rep_ident 85 \\
      --min_rep_cov 40 \\
      --min_mob_ident 85 \\
      --min_mob_cov 40 \\
      --min_con_ident 85 \\
      --min_con_cov 40
    """
}