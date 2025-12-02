process AMR_2 {
    tag "AMRFinder search for ${sample_code}"
    label 'amrfinder_plus'
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.amrfinderplus.docker}" :
        params.amrfinderplus.docker }"

    publishDir "${params.outdir}/3-AMR/AMRFinder", mode: 'copy'

    input:
    tuple val(sample_code), path(assembly_file)

    output:
    path("${sample_code}_amrfinder_report.tsv"), emit: amrfinder_report

    script:
    """
    amrfinder -n ${assembly_file} -o ${sample_code}_amrfinder_report.tsv
    """
}