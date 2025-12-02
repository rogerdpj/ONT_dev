process BAKTA {
    tag "BAKTA annotation for ${sample_code}"
    label 'bakta_annotations'
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.bakta.docker}" :
        params.bakta.docker }"

    publishDir "${params.outdir}/2-Assembly/3-Annotations", mode: 'copy', saveAs: { filename ->
        if (filename.endsWith(".gff3")) {
            return "bakta/${sample_code}/${sample_code}.gff3"
        } else if (filename.endsWith(".faa")) {
            return "bakta/${sample_code}/${sample_code}.faa"
        } else if (filename.endsWith(".fna")) {
            return "bakta/${sample_code}/${sample_code}.fna"
        } else if (filename.endsWith(".gbff")) {
            return "bakta/${sample_code}/${sample_code}.gbff"
        } else if (filename.endsWith(".txt")) {
            return "bakta/${sample_code}/${sample_code}.txt"
        } else if (filename.endsWith(".json")) {
            return "bakta/${sample_code}/${sample_code}.json"
        } else {
            return null
        }
    }

    input:
    tuple val(sample_code), path(assembly_file)

    output:
    tuple val(sample_code), path("annotations_${sample_code}/${sample_code}_consensus_wrapped.gff3"), emit: bakta_gff3
    path "annotations_${sample_code}/${sample_code}_consensus_wrapped.faa", emit: bakta_faa
    path "annotations_${sample_code}/${sample_code}_consensus_wrapped.ffn", emit: bakta_ffn
    path "annotations_${sample_code}/${sample_code}_consensus_wrapped.gbff", emit: bakta_gbff
    path "annotations_${sample_code}/${sample_code}_consensus_wrapped.txt", emit: bakta_txt
    path "annotations_${sample_code}/${sample_code}_consensus_wrapped.json", emit: bakta_json
    tuple val(sample_code), path("annotations_${sample_code}/${sample_code}_consensus_wrapped.gff3"), path("annotations_${sample_code}/${sample_code}_consensus_wrapped.fna"), emit: conv_gff

    script:

    """
    bakta --db /data/db-light --threads ${task.cpus} --keep-contig-headers --output annotations_${sample_code} ${assembly_file}

    """
}