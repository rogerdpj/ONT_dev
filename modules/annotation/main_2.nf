process ENRICHMENT_ANNOTATION {
    tag "Enriching Bakta with Prokka for ${sample_code}"
    label 'annotation'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://jimmlucas/enrichment:v1.0.0" :
        "jimmlucas/enrichment:v1.0.0" }"

    publishDir "${params.outdir}/2-Assembly/3-Annotations/ENRICHED_${sample_code}", mode: 'copy'

    input:
    tuple val(sample_code), path(prokka_file), path(bakta_file), path(assembly_file)

    output:
    path "enriched_${sample_code}.gff3", emit: enriched_gff3
    path "cds_${sample_code}.fa", emit: cds_fasta
    path "protein_${sample_code}.fa", emit: protein_fasta
    path "enrichment_report_${sample_code}.txt", emit: report

    script:
    """
    set -euo pipefail
    
    # 1) Inicializar reporte
    echo "========================================" > enrichment_report_${sample_code}.txt
    echo "ENRIQUECIMIENTO DE ANOTACIÓN BACTERIANA" >> enrichment_report_${sample_code}.txt
    echo "========================================" >> enrichment_report_${sample_code}.txt
    
    # 2) Preparar script de enriquecimiento
    cp ${projectDir}/bin/annotation/enrich_bakta_with_prokka.sh .
    chmod +x enrich_bakta_with_prokka.sh
    
    # 3) Ejecutar enriquecimiento (Mantiene coordenadas de Bakta)
    ./enrich_bakta_with_prokka.sh \
        --bakta ${bakta_file} \
        --prokka ${prokka_file} \
        --output enriched_${sample_code}.gff3 \
        --verbose >> enrichment_report_${sample_code}.txt 2>&1
    
    # 4) Limpieza específica para bacterias antes de gffread
    # - Eliminamos líneas con strand '?' (como oriC) que rompen gffread
    # - Eliminamos tabs accidentales en la columna de atributos que causan warnings
    echo "[INFO] Limpiando GFF para extracción de secuencias..." >> enrichment_report_${sample_code}.txt
    
    grep -v \$'\t?\t' enriched_${sample_code}.gff3 | sed 's/\t/ /g9' > enriched_clean.gff3

    # 5) Extraer CDS y Proteínas (FASTA)
    # Usamos -y para proteínas y -x para CDS, esencial para validación de SNPs
    echo "[INFO] Generando archivos FASTA..." >> enrichment_report_${sample_code}.txt
    gffread enriched_clean.gff3 \
        -g ${assembly_file} \
        -x cds_${sample_code}.fa \
        -y protein_${sample_code}.fa
    
    echo "[INFO] Proceso bacteriano completado." >> enrichment_report_${sample_code}.txt
    """
}