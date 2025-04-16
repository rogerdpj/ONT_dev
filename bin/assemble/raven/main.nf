process SUB_SAMPLE_3 {
    tag "Assemble with Raven - ${barcode_id}"

    input:
    tuple val(barcode_id), path(barcode_file), val(genome_size), val(sample_code)

    output:
    tuple val(sample_code), path("raven_output_${sample_code}.fasta"), emit: raven_aseembly_file

    script:
    """
    mkdir -p raven_output_${sample_code}
    raven ${barcode_file} > raven_output_${sample_code}/${sample_code}_assembly.fasta --threads 8
    mv raven_output_${sample_code}/${sample_code}_assembly.fasta raven_output_${sample_code}.fasta 
    """
}