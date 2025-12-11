process AGAT {
    tag "Merging annotations with AGAT for ${sample_code}"
    label 'agat_enhanced'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.agat.docker}" :
        params.agat.docker }"

    publishDir "${params.outdir}/2-Assembly/3-Annotations/AGT_${sample_code}", mode: 'copy'
    
    input:
    tuple val(sample_code), path(prokka_file), path(bakta_file), path(assembly_file)

    output:
    path "final_${sample_code}.gff3", emit: combine_gff3
    path "statistics_report_${sample_code}.txt", emit: statistics_report
    path "cds_${sample_code}.fa", emit: cds_fasta
    path "protein_${sample_code}.fa", emit: protein_fasta
    path "validation_report_${sample_code}.txt", emit: validation_report, optional: true

    script:
    """
    set -euo pipefail

    echo "Usando FASTA original: ${assembly_file}" > validation_report_${sample_code}.txt

    # 1) Convertir GFF de Prokka a formato GFF3 válido
    echo "Convirtiendo Prokka GFF a GFF3..." >> validation_report_${sample_code}.txt
    agat_convert_sp_gxf2gxf.pl --gff ${prokka_file} --output prokka_${sample_code}.gff3

    # 2) Fusionar Prokka + Bakta
    echo "Fusionando anotaciones Prokka + Bakta..." >> validation_report_${sample_code}.txt
    agat_sp_merge_annotations.pl \
        --gff prokka_${sample_code}.gff3 \
        --gff ${bakta_file} \
        --out combined_${sample_code}.gff3

    # 3) Corregir fases de codón
    echo "Corrigiendo fases de CDS..." >> validation_report_${sample_code}.txt
    agat_sp_fix_cds_phases.pl \
        --gff combined_${sample_code}.gff3 \
        --fasta ${assembly_file} \
        --output fixed_combined_${sample_code}.gff3

    # 4) Conservar isoforma más larga
    echo "Conservando isoforma más larga..." >> validation_report_${sample_code}.txt
    agat_sp_keep_longest_isoform.pl \
        --gff fixed_combined_${sample_code}.gff3 \
        --output longest_${sample_code}.gff3

    # 5) Filtrar genes incompletos
    echo "Filtrando genes incompletos..." >> validation_report_${sample_code}.txt
    agat_sp_filter_incomplete_gene_coding_models.pl \
        --gff longest_${sample_code}.gff3 \
        --fasta ${assembly_file} \
        --output filtered_${sample_code}.gff3

    # 6) Definir GFF final (por claridad)
    cp filtered_${sample_code}.gff3 final_${sample_code}.gff3

    # 7) Extraer CDS y proteínas
    echo "Extrayendo secuencias CDS y proteínas..." >> validation_report_${sample_code}.txt
    gffread final_${sample_code}.gff3 \
        -g ${assembly_file} \
        -x cds_${sample_code}.fa \
        -y protein_${sample_code}.fa

    # 8) Estadísticas de anotación
    echo "Generando estadísticas..." >> validation_report_${sample_code}.txt
    agat_sp_statistics.pl \
        --gff final_${sample_code}.gff3 \
        --output statistics_report_${sample_code}.txt

    echo "Proceso completado exitosamente." >> validation_report_${sample_code}.txt
    """
}