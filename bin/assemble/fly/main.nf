process SUB_SAMPLE_2 {
    tag "ASSAMBLE FLY LONG READS ${sample_code}"
    label 'fly_long_reads'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.long_read.docker}" :
        params.long_read.docker }"
        
    publishDir "${params.outdir}/2-Assembly/1-Fly_structural", mode: 'copy'

    input:

    tuple val(barcode_id), path(barcode_file), val (genome_size), val (sample_code)

    output:

    tuple val(sample_code),path("flye_output_${sample_code}/assembly.fasta"), emit: fly_assambly_tuple
    tuple val(sample_code),path("flye_output_${sample_code}/assembly_info.txt"), emit: info_cov
    tuple val(sample_code),path("flye_output_${sample_code}/assembly_graph.gfa"), emit: grafic_assemble
    tuple val(sample_code),path("dedup_${sample_code}_NanoStat.txt"), emit: quality_control

    script:

    """
    # Paso 1: Eliminar IDs duplicados en las lecturas usando seqkit
    seqkit rmdup -s -i ${barcode_file} -o dedup_${sample_code}.fastq

    # Generar reporte de calidad con NanoStat para evaluar resultados
    NanoStat --fastq dedup_${sample_code}.fastq > dedup_${sample_code}_NanoStat.txt

    # Paso 2: Ejecutar Flye usando el archivo sin duplicados
    flye --nano-raw dedup_${sample_code}.fastq --out-dir flye_output_${sample_code} --genome-size ${genome_size} --plasmids --threads 8

    """
}