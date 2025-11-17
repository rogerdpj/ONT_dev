process DNAAPLER {
    tag "dnaapler ${sample_code}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.autocycler.docker}" :
        params.autocycler.docker }"

    publishDir "${params.outdir}/2-Assembly/2-Dnaapler", mode: 'copy'

    input:
    tuple val(sample_code), path(gfa_file)

    output:
    tuple val(sample_code), path("${sample_code}.fasta"), emit: reoriented_assembly
    path("dnaapler/dnaapler_reoriented.gfa"), emit: reoriented_gfa

    script:

    """    
    echo "Running DNAAPLER for sample: ${sample_code}"
    
    # Reorient circular sequences with Dnaapler
    dnaapler all -i ${gfa_file} -o dnaapler -t 8

    # Convert the reoriented GFA back to FASTA
    autocycler gfa2fasta -i dnaapler/dnaapler_reoriented.gfa -o ${sample_code}.fasta

    """

}
