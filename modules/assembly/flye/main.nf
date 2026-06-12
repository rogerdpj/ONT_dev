process ASSEMBLY {
    tag "Flye assembly of ${sample_code}/${barcode_id} "
    label 'env_flye'
        
    publishDir "${params.outdir}/2-Assembly/1-Flye_structural", mode: 'copy', pattern: "flye_output_${sample_code}/*"
    publishDir "${params.outdir}/2-Assembly/1-Flye_structural", mode: 'copy', pattern: "${sample_code}_NanoStat.txt"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*version.txt"


    input:

    tuple val(barcode_id), path(barcode_file), val (genome_size), val (sample_code)

    output:

    tuple val(sample_code), path("flye_output_${sample_code}/assembly.fasta"), emit: assembly
    tuple val(sample_code), path("flye_output_${sample_code}/assembly_info.txt"), emit: info_cov
    tuple val(sample_code), path("flye_output_${sample_code}/assembly_graph.gfa"), emit: graph
    tuple val(sample_code), path("${sample_code}_NanoStat.txt"), emit: qc
    path "${task.process}.version.txt", emit: versions

    script:

    """    
    set -euo pipefail
    
    echo -e "flye\t\$(flye --version 2>&1 | head -n 1)" > ${task.process}.version.txt
    echo -e "nanostat\t\$(NanoStat --version 2>&1)" >> ${task.process}.version.txt

    INPUT=${barcode_file}
  
    # QC
    NanoStat --fastq \${INPUT} > ${sample_code}_NanoStat.txt
    
    # Assembly
    flye \\
        --nano-hq \${INPUT} \\
        --out-dir flye_output_${sample_code} \\
        --genome-size ${genome_size} \\
        --iterations 0 \\
        --asm-coverage 40 \\
        --threads ${task.cpus}
    """
}