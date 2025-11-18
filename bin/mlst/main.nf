process MLST {
    tag "MLST-annotation process ${sample_code}"
    label 'env_mlst'
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.short_wgs.docker}" :
        params.short_wgs.docker }"
    
    publishDir "${params.outdir}/4-MLST", mode: 'copy'

    input:
    tuple val(sample_code), path(assembly_file)

    output:
    path("*.mlst.tab"), emit: 'tab'
    path("*.mlst.json"), emit: 'json'

    script:
    """
    mlst --threads ${task.cpus} --json ${sample_code}.mlst.json ${assembly_file} > ${sample_code}.mlst.tab
    """
}
