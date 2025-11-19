process PROKKA {
    tag "PROKKA ANNOTATION"
    label 'prokka_annotations'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.prokka.docker}" :
        params.prokka.docker }"
    
    publishDir "${params.outdir}/2-Assembly/3-Annotations", mode: 'copy', saveAs: { filename ->
        if (filename.endsWith(".gff")) {
            return "prokka/${sample_code}/${sample_code}.gff"
        } else if (filename.endsWith(".faa")) {
            return "prokka/${sample_code}/${sample_code}.faa"
        } else if (filename.endsWith(".fna")) {
            return "prokka/${sample_code}/${sample_code}.fna"
        } else {
            return null
        }
    }

    input:
    tuple val (sample_code), path(assembly_file)

    output:
    tuple val(sample_code), path("annotations_${sample_code}/${sample_code}_wildtype.gff"), emit: prokka_gff
    path "annotations_${sample_code}/${sample_code}_wildtype.faa", emit: prokka_faa
    path "annotations_${sample_code}/${sample_code}_wildtype.fna", emit: prokka_fna

    script:
    """
    prokka --outdir annotations_${sample_code} --prefix ${sample_code}_wildtype --kingdom Bacteria ${assembly_file}
    """
}