process AGT {
    tag "MERGE ANNOTATIONS"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.agat.docker}" :
        params.agat.docker }"

    publishDir "${params.outdir}/2-Assembly/3-Annotations/AGT_${sample_code}", mode: 'copy'
    input:
    path prokka_file
    path bakta_file
    tuple val(sample_code), path(assembly_file)

    output:
    path "fixed_combined_${sample_code}.gff3", emit: combine_gff3
    path "statistics_report_${sample_code}.txt", emit: statistics_report
    path "cds_${sample_code}.fa", emit: cds_fasta
    path "protein_${sample_code}.fa", emit: protein_fasta

    script:
    """
    echo "Limpiando headers del FASTA con IDs únicos..."
    awk '/^>/{print ">contig_" ++i; next} {print}' ${assembly_file} > assembly_clean.fasta

    # Convertir GFF de Prokka a formato GFF3 válido
    agat_convert_sp_gxf2gxf.pl --gff ${prokka_file} --output prokka_${sample_code}.gff3

    # Extraer contig IDs originales y nuevos
    grep "^>" ${assembly_file} | sed 's/^>//; s/ .*//' > prokka_contigs.txt
    grep "^>" assembly_clean.fasta | sed 's/^>//' > bakta_contigs.txt

    # Validar tamaños iguales
    wc -l prokka_contigs.txt
    wc -l bakta_contigs.txt

    # Mapeo 1:1 suponiendo orden igual
    paste prokka_contigs.txt bakta_contigs.txt > contig_name_map.tsv

    # Renombrar contigs en Prokka
    agat_sq_rename_seqid.pl --gff prokka_${sample_code}.gff3 --tsv contig_name_map.tsv --output prokka_${sample_code}_renamed.gff3

    # Fusionar Prokka + Bakta
    agat_sp_merge_annotations.pl --gff prokka_${sample_code}_renamed.gff3 --gff ${bakta_file} --out combined_${sample_code}.gff3

    # Corregir fases de codón
    agat_sp_fix_cds_phases.pl --gff combined_${sample_code}.gff3 --fasta assembly_clean.fasta --output fixed_combined_${sample_code}.gff3

    # Conservar isoforma más larga
    agat_sp_keep_longest_isoform.pl --gff fixed_combined_${sample_code}.gff3 --output longest_${sample_code}.gff3

    # Filtrar genes incompletos
    agat_sp_filter_incomplete_gene_coding_models.pl --gff longest_${sample_code}.gff3 --fasta assembly_clean.fasta --output filtered_${sample_code}.gff3

    # Validar consistencia de contig IDs
    grep "^>" assembly_clean.fasta | sed 's/^>//' | sort > ids_fasta.txt
    awk '\$0 !~ /^#/ {print \$1}' filtered_${sample_code}.gff3 | sort | uniq > ids_gff.txt
    comm -23 ids_gff.txt ids_fasta.txt > mismatched_ids.txt || true

    # Renombrar si hay incompatibilidades
    if [ -s mismatched_ids.txt ]; then
        echo "Hay contigs con nombres incompatibles, ajustando..."
        cut -f2,1 contig_name_map.tsv > map_for_final.tsv
        agat_sq_rename_seqid.pl --gff filtered_${sample_code}.gff3 --tsv map_for_final.tsv --output final_${sample_code}.gff3
    else
        cp filtered_${sample_code}.gff3 final_${sample_code}.gff3
    fi

    # Extraer CDS y proteínas
    gffread final_${sample_code}.gff3 -g assembly_clean.fasta -x cds_${sample_code}.fa -y protein_${sample_code}.fa

    # Estadísticas de anotación
    agat_sp_statistics.pl --gff final_${sample_code}.gff3 --output statistics_report_${sample_code}.txt
    """
}