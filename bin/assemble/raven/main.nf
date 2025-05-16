process SUB_SAMPLE_3 {
    tag "Assemble with Raven - ${barcode_id}"

    input:
    tuple val(barcode_id), path(barcode_file), val(genome_size), val(sample_code)

    output:
    tuple val(sample_code), path("raven_output_${sample_code}.fasta"), emit: raven_aseembly_file

    script:
    """
        # Verificar que el archivo de lectura existe y no está vacío
    if [[ ! -s "${barcode_file}" ]]; then
        echo "❌ ERROR: El archivo de lectura '${barcode_file}' está vacío o no existe." >&2
        exit 1
    fi

    # Descomprimir si es necesario
    if [[ "${barcode_file}" == *.gz ]]; then
        gunzip -c "${barcode_file}" > input_reads.fastq
    else
        cp "${barcode_file}" input_reads.fastq
    fi

    mkdir -p raven_output_${sample_code}
    raven input_reads.fastq --threads ${task.cpus} --drop-reads --disable-checkpoints > raven_output_${sample_code}/${sample_code}_assembly.fasta 2> raven_error.log
    mv raven_output_${sample_code}/${sample_code}_assembly.fasta raven_output_${sample_code}.fasta 
    """
}

