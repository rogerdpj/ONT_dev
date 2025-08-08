process DNAAPLER {

    container "$params.autocycler.docker"

    publishDir "data/out/3-dnaapler", mode: 'copy'

    input:
    tuple val(sample_code), path(gfa_file)

    output:
    tuple val(sample_code), path("${sample_code}.fasta"), emit: reoriented_assembly


    script:

    """    
    echo "Running DNAAPLER for sample: ${sample_code}"
    
    # Reorient circular sequences with Dnaapler
    dnaapler all -i ${gfa_file} -o dnaapler -t 8

    # Convert the reoriented GFA back to FASTA
    autocycler gfa2fasta -i dnaapler/dnaapler_reoriented.gfa -o ${sample_code}.fasta

    """

}
