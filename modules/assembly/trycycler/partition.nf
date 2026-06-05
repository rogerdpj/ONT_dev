process PARTITION {
    tag "Partitioning reads for ${sample_code}"

    publishDir "${params.outdir}/9-partition", mode: 'copy'

    container "$params.trycyler.docker"

    input:
    tuple val(sample_code), val(barcode_id), path(cluster_dir)
    tuple val(barcode_id), path(reads_file)

    output:
    tuple val(sample_code), val(barcode_id), path("${cluster_dir}/4_reads.fastq"), emit: partition_output
    tuple val(sample_code), val(barcode_id), path("${cluster_dir}/"), emit: partition_dir

    
    script:
    """
    # Ejecutar Trycycler PARTITION en el directorio reconciliado
    trycycler partition --cluster_dir ${cluster_dir} --reads ${reads_file} 2>&1 | tee ${cluster_dir}/partition.log

    # Verificar que el archivo de salida fue generado
    if [[ ! -f "${cluster_dir}/4_reads.fastq" ]]; then
        echo "ERROR: Partición de lecturas no fue generada correctamente." >&2
        exit 1
    fi
    """
}