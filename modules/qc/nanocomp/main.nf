process NANOCOMP {
    tag "Nanocomp: comparison"
    label 'env_nanocomp'

    publishDir "${params.outdir}/1-QC/data_QC", mode: 'copy', pattern: "Nanocomp*"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"

    input:
    tuple val(id), val(labels), path(files)

    output:
    path "Nanocomp", emit: report
    path "${task.process}.version.txt", emit: versions

    script:
    def flat_files  = files.join(' ')
    def flat_labels = labels.join(' ')
    """
    set -euo pipefail

    echo "nanocomp\t\$((NanoComp --version 2>&1 || NanoComp -h 2>&1) | grep -oE '[0-9]+\\.[0-9]+(\\.[0-9]+)?' | head -n 1 )" > ${task.process}.version.txt

    NanoComp \\
            --fastq ${flat_files} \\
            --names ${flat_labels} \\
            -o Nanocomp
    """
}
