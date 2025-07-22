process MSA {
    tag "Multiple Sequence Alignment for ${sample_code}"

    publishDir "${params.outdir}/8-msa", mode: 'copy'

    container "$params.trycyler.docker"

    input:
    tuple val(sample_code), val(barcode_id), path(cluster_dir)

    output:
    tuple val(sample_code), val(barcode_id), path("${cluster_dir}/3_msa.fasta"), emit: msa_output
    tuple val(sample_code), val(barcode_id), path("${cluster_dir}/"), emit: msa_dir

    script:
    """
    # Ejecutar Trycycler MSA en el directorio reconciliado
    trycycler msa --cluster_dir ${cluster_dir} 2>&1 | tee ${cluster_dir}/msa.log

    # Verificar que el archivo de salida existe antes de terminar
    if [[ ! -f "${cluster_dir}/3_msa.fasta" ]]; then
        echo "ERROR: 3_msa.fasta no fue generado." >&2
        exit 1
    fi
    """
}