process TRIMMING {
    tag "TRIM:${barcode_id}"
    label 'env_trimming'

    publishDir "${params.outdir}/logs/trimming", mode: 'copy', pattern: "*.log"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"

    input:
    tuple val(barcode_id), path(fastq_file), val(target_bases)
    
    output:
    tuple val(barcode_id), path("${barcode_id}_clean.fastq"), emit: reads_trimmed
    tuple val(barcode_id), path("${barcode_id}_clean.fastq.gz"), emit: reads_trimmed_gz
    tuple val(barcode_id), path("filtlong_${barcode_id}.log"), emit: filtlong_log
    tuple val(barcode_id), path("porechop_${barcode_id}.log"), emit: porechop_log
    path "${task.process}.version.txt", emit: versions

    
    script:
    """
    echo "filtlong: \$(filtlong --version 2>&1)" > ${task.process}.version.txt
    echo "porechop: \$(porechop --version 2>&1)" >> ${task.process}.version.txt

    filtlong \
        --min_length ${params.min_length ?: 1000} \
        --target_bases ${target_bases} \
        ${fastq_file} \
        > filtered_${barcode_id}.fastq \
        2> filtlong_${barcode_id}.log

    porechop \
        -i filtered_${barcode_id}.fastq \
        -o ${barcode_id}_clean.fastq \
        --threads ${task.cpus} \
        --discard_middle \
        > porechop_${barcode_id}.log 2>&1

    gzip -kf ${barcode_id}_clean.fastq
    """
}