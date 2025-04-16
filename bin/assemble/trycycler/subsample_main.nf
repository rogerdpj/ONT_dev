process SUB_SAMPLE {
    tag "SUB SAMPLE TRYCYCLER FROM LONG READS"

    container "$params.trycyler.docker"

    input:

    tuple val(barcode_id), path(barcode_file)
    val genome_size_map

    output:

    tuple val(barcode_id), path("*")


    script:

    def genome_size = genome_size_map[barcode_id]
    """
    trycycler subsample \
        --reads ${barcode_file} \
        --out_dir subsample_${barcode_id} \
        --genome_size ${genome_size}
    
    """

}

process COMBINE_SUBSAMPLED_READS {
    tag "Combine subsampled reads - ${barcode_id}"

    container "$params.trycyler.docker"

    input:
    tuple val(barcode_id), path(subsample_dir)

    output:
    tuple val(barcode_id), path("combine_${barcode_id}.fastq")

    script:
    """
    # Verificamos que existan archivos .fastq.gz o .fastq
    files=\$(ls ${subsample_dir}/*.fastq* 2>/dev/null || true)
    if [[ -z "\$files" ]]; then
        echo "❌ ERROR: No se encontraron archivos .fastq en ${subsample_dir}" >&2
        exit 1
    fi

    # Detectamos si están comprimidos
    if ls ${subsample_dir}/*.fastq.gz >/dev/null 2>&1; then
        echo "⚠️ Detectado .fastq.gz, usando zcat"
        zcat ${subsample_dir}/*.fastq.gz > combine_${barcode_id}.fastq
    else
        echo "✅ Archivos planos detectados, usando cat"
        cat ${subsample_dir}/*.fastq > combine_${barcode_id}.fastq
    fi
    """
}
