process NANOCOMP {
    tag "Nanocomp process"

    publishDir "${params.outdir}/1-QC/data_QC", mode: 'copy'

    input:
    path (barcode_dir)
    path (barcode_id_clean)

    output:

    path "Nanocomp"

    script:

    """
    source activate nanopore    
    NanoComp --fastq ${barcode_dir} ${barcode_id_clean} -o Nanocomp
    
    """
}
