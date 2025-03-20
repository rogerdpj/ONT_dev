process RECONCILE_ASSEMBLE {
    tag "Reconcile assemblies for barcode ${sample_code}"

    publishDir "${params.outdir}/7-reconcile_assemble", mode: 'copy'

    container "$params.trycyler.docker"

    input:
    path(contigs_dir)
    tuple val(sample_code), val(barcode_id), path(barcodefile), val (genome_size)

    output:
    tuple val(sample_code), val(barcode_id), path("cluster_001/2_all_seqs.fasta"), emit: reconciled_seqs
    tuple val(sample_code), val(barcode_id), path("cluster_001/"), emit: reconciled_dir
    path("*")


    script:
    
    """
    
    # Ejecutar Trycycler reconcile en el directorio de contigs
    trycycler reconcile --cluster_dir "${contigs_dir}" \\
                        --reads ${barcodefile} \\
                        --min_1kbp_identity 10.0 \\
                        --threads 8 2>&1 | tee ${contigs_dir}/reconcile.log

    
    cp ${contigs_dir}/2_all_seqs.fasta .
    """

}
