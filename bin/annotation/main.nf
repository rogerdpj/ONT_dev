process AGT {
    tag "MERGE ANNOTATIONS"
    label 'agat_enhanced'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.agat.docker}" :
        params.agat.docker }"

    publishDir "${params.outdir}/2-Assembly/3-Annotations", mode: 'copy'
    
    input:
    tuple val(sample_code), path(prokka_file), path(bakta_file), path(assembly_file)

    output:
    path "fixed_combined_${sample_code}.gff3", emit: combine_gff3
    path "statistics_report_${sample_code}.txt", emit: statistics_report
    path "cds_${sample_code}.fa", emit: cds_fasta
    path "protein_${sample_code}.fa", emit: protein_fasta

    script:
    """
    agat_convert_sp_gxf2gxf.pl --gff ${prokka_file} --output prokka_${sample_code}.gff3

    agat_sp_merge_annotations.pl --gff prokka_${sample_code}.gff3 --gff ${bakta_file} --out combined_${sample_code}.gff3

    agat_sp_fix_cds_phases.pl --gff combined_${sample_code}.gff3 --fasta ${assembly_file} --output fixed_combined_${sample_code}.gff3

    gffread fixed_combined_${sample_code}.gff3 -g ${assembly_file} -x cds_${sample_code}.fa -y protein_${sample_code}.fa

    agat_sp_statistics.pl --gff fixed_combined_${sample_code}.gff3 --output statistics_report_${sample_code}.txt
    """
}