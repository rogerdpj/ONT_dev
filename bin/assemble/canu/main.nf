process SUB_SAMPLE_1 {
    tag "Assemble with Canu - ${sample_code}"

    input:
    tuple val(barcode_id), path(barcode_file), val(genome_size_map), val(sample_code)

    output:
    path("canu_output_${sample_code}")
    tuple val(sample_code), path("canu_output_${sample_code}.fasta"), emit: assembly_canu_file

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

    # Ejecutar Canu con el archivo descomprimido
    canu -p ${sample_code}_assembly -d canu_output_${sample_code} \\
        genomeSize=${genome_size_map} \\
        -nanopore-raw input_reads.fastq \\
        maxThreads=8

    # Mover ensamblado final
    mv canu_output_${sample_code}/${sample_code}_assembly.contigs.fasta canu_output_${sample_code}.fasta
    """
}
