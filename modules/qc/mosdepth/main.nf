process MOSDEPTH {

    tag "Mosdepth: ${sample_code}"
    label 'env_mosdepth'

    publishDir "${params.outdir}/1-QC/genome_QC/3-Mosdepth", mode: 'copy', pattern: "${sample_code}.*.txt"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"

    input:
    tuple val(sample_code), path(reads), path(fasta)

    output:
    tuple val(sample_code), path("${sample_code}.mosdepth.summary.txt"), emit: summary
    tuple val(sample_code), path("${sample_code}.mosdepth.global.dist.txt"), emit: dist
    path "${task.process}.version.txt", emit: versions

    script:
    """
    set -euo pipefail

    echo -e "mosdepth\t\$(mosdepth --version 2>&1 | awk '{print \$2}')" > ${task.process}.version.txt

    # Index reference
    samtools faidx ${fasta}

    # Align reads → BAM
    minimap2 -ax lr:hq ${fasta} ${reads} -t ${task.cpus} | \
        samtools sort -@ ${task.cpus} -o ${sample_code}.bam

    samtools index ${sample_code}.bam

    mosdepth \
        -n \
        -x \
        -t ${task.cpus} \
        ${sample_code} \
        ${sample_code}.bam
    """
}