process CONSENSUS {
    tag "Generating final consensus for ${sample_code}"

    publishDir "${params.outdir}/10-consensus", mode: 'copy'

    container "$params.trycyler.docker"

    input:
    tuple val(sample_code), val(barcode_id), path(cluster_dir)

    output:
    tuple val(sample_code), val(barcode_id), path("${cluster_dir}/7_final_consensus.fasta"), emit: consensus_output

    script:
    """
    # Ejecutar Trycycler CONSENSUS en el directorio del cluster
    trycycler consensus --cluster_dir ${cluster_dir} 2>&1 | tee ${cluster_dir}/consensus.log

    # Verificar que el archivo de salida fue generado correctamente
    if [[ ! -f "${cluster_dir}/7_final_consensus.fasta" ]]; then
        echo "ERROR: El archivo de consenso no fue generado correctamente." >&2
        exit 1
    fi
    """
}
