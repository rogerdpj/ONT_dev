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
    cat ${subsample_dir}/*.fastq > combine_${barcode_id}.fastq
    """
}