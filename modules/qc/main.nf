process QC {
    tag "QC: ${barcode}"
    label 'env_nanoplot'
    cpus 4

    cache 'deep'
    
    publishDir "${params.outdir}/1-QC/data_QC/Nanoplot", mode: 'copy', pattern: "Nanoplot_*"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"

    input:
    tuple val(barcode), path(barcode_dir)

    output:
    tuple val(barcode), path("barcode_${barcode}.fastq.gz"), emit: fastq_combine
    tuple val(barcode), path("Nanoplot_${barcode}/"), emit: nanoplot_output
    path "${task.process}.version.txt", emit: versions


    script:
    """
    echo "nanoPlot\t\$(NanoPlot --version 2>&1 | grep -oE '[0-9]+\\.[0-9]+(\\.[0-9]+)?' | head -n 1)" > ${task.process}.version.txt

    cat ${barcode_dir}/*.fastq.gz > barcode_${barcode}.fastq.gz || exit 1

    NanoPlot \\
        -t ${task.cpus}  \\
        -o Nanoplot_${barcode} \\
        --fastq barcode_${barcode}.fastq.gz
    """
}