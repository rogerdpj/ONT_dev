process NANOCOMP {
    tag "Nanocomp comparison"
    label 'env_nanocomp'

    publishDir "${params.outdir}/1-QC/data_QC", mode: 'copy', pattern: "Nanocomp*"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"


    input:
    tuple val(id), val(labels), path(files)

    output:
    path "Nanocomp", emit: report
    path "${task.process}.version.txt", emit: versions

    script:
    """
    set -euo pipefail

    echo "nanocomp\t\$(NanoComp --version 2>&1 || NanoComp -h 2>&1 | head -n 1)" > ${task.process}.version.txt

    for i in \$(seq 0 \$((\${#files[@]}-1))); do
        ln -sf "\${files[\$i]}" "${id}_\${labels[\$i]}.fastq.gz"
    done

    NanoComp \\
        --fastq *.fastq.gz \\
        -o Nanocomp
    """
}
