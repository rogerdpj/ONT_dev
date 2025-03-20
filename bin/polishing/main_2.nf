process POLISH {
    tag "Polishing consensus with Polypolish for ${barcode_id}"

    publishDir "${params.outdir}/11-polished", mode: 'copy'

    container "$params.polypolish.docker"

    input:
    tuple val(sample_code), val(barcode_id), path(final_consensus)
    tuple val(barcode_id), path(short_reads)
    output:
    tuple val(sample_code), val(barcode_id), path("${barcode_id}_polished.fasta"), emit: polished_output

    script:
    """
    # Ejecutar Polypolish para mejorar el ensamblado final
    polypolish ${final_consensus} ${short_reads[1]} ${short_reads[2]} > ${barcode_id}_polished.fasta

    # Verificar que el archivo de salida fue generado correctamente
    if [[ ! -f "${barcode_id}_polished.fasta" ]]; then
        echo "ERROR: El archivo de consenso pulido no fue generado correctamente." >&2
        exit 1
    fi
    """
}