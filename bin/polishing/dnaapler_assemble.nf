process DNAAPLER {
    tag "Dnaapler reorientation of ${sample_code}"
    label 'dna_apler'


    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.autocycler.docker}" :
        params.autocycler.docker }"

    publishDir "${params.outdir}/2-Assembly/2-Dnaapler", mode: 'copy'

    input:
    tuple val(sample_code), path(consensus_fasta)

    output:
    tuple val(sample_code), path("${sample_code}/${sample_code}_reoriented.fasta"), emit: reoriented_assembly


    script:

    """    
    echo "Running DNAAPLER for sample: ${sample_code}"
    
    # Reorient circular sequences with Dnaapler
    dnaapler all -i ${consensus_fasta} -t 8 -o ${sample_code}

    mv ${sample_code}/dnaapler_reoriented.fasta ${sample_code}/${sample_code}_reoriented.fasta

    """

}
