process ALIGN_SHORT_READS {
    tag "Aligning short reads for ${barcode_id}"

    publishDir "${params.outdir}/10-Polished/short_alignment", mode: 'copy'

    container "$params.short_wgs.docker"

    input:
    tuple val(sample_code), val(barcode_id), path(final_consensus)
    tuple val(barcode_id), path(short_reads)

    output:
    tuple val(sample_code), val(barcode_id), path("alignments_1.sam"), emit: aligned_sam1
    tuple val(sample_code), val(barcode_id), path("alignments_2.sam"), emit: aligned_sam2

    script:
    """
    # Indexar el ensamblado final
    bwa index ${final_consensus}

    # Alinear cada set de lecturas de manera independiente
    bwa mem -t 16 -a ${final_consensus} ${short_reads[0]} > alignments_1.sam
    bwa mem -t 16 -a ${final_consensus} ${short_reads[1]} > alignments_2.sam

    # Convertir a BAM, ordenar e indexar
    samtools view -bS alignments_1.sam | samtools sort -o alignments_1.sorted.bam
    samtools view -bS alignments_2.sam | samtools sort -o alignments_2.sorted.bam
    samtools merge reads.sorted.bam alignments_1.sorted.bam alignments_2.sorted.bam
    samtools index reads.sorted.bam
    """
}

process FILTER_ALIGNMENTS {
    tag "Filtering alignments with Polypolish for ${barcode_id}"

    publishDir "${params.outdir}/10-filtered", mode: 'copy'

    container "$params.polypolish.docker"

    input:
    tuple val(sample_code), val(barcode_id), path(aligned_sam1)
    tuple val(sample_code), val(barcode_id), path(aligned_sam2)

    output:
    tuple val(barcode_id), path("${barcode_id}_filtered_1.sam"), path("${barcode_id}_filtered_2.sam"), emit: filtered_sam

    script:
    """
    # Filtrar alineaciones para eliminar errores en regiones repetitivas
    polypolish filter --in1 ${aligned_sam1} --in2 ${aligned_sam2} --out1 ${barcode_id}_filtered_1.sam --out2 ${barcode_id}_filtered_2.sam
    
    """
}

process POLISH {
    tag "Polishing consensus with Polypolish for ${barcode_id}"

    publishDir "${params.outdir}/11-polished", mode: 'copy'

    container "$params.polypolish.docker"

    input:
    tuple val(sample_code), val(barcode_id), path(final_consensus)
    tuple val(barcode_id), path(filtered_reads_1), path(filtered_reads_2)

    output:
    tuple val(sample_code), path("${barcode_id}_polished.fasta"), emit: polished_output

    script:
    """
    # Aplicar polypolish con los archivos SAM filtrados
    polypolish polish ${final_consensus} ${filtered_reads_1} ${filtered_reads_2} > ${barcode_id}_polished.fasta
    """
}