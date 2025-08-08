process TRIMMING {
    tag "prunning process"
    
    input:
    tuple val(barcode_id), path(fastq_file)
    
    output:
    tuple val(barcode_id), path("${barcode_id}_clean.fastq"), emit: barcodefile_gz
    tuple val(barcode_id), path("${barcode_id}_NanoStat.log"), emit: stat_post_trimming
    tuple val(barcode_id), path("${barcode_id}_clean.fastq.gz"), emit: barcodefile_compress
    
    script:
    """
    filtlong --min_length ${params.min_length ?: 1000} --keep_percent ${params.keep_percent ?: 90} --min_mean_q ${params.min_mean_q ?: 10} ${fastq_file} > filtered_${barcode_id}.fastq

    porechop -i filtered_${barcode_id}.fastq -o ${barcode_id}_clean.fastq > porechop.log 2>&1

    NanoStat --fastq ${barcode_id}_clean.fastq > ${barcode_id}_NanoStat.log

    gzip -kf ${barcode_id}_clean.fastq
    """
}