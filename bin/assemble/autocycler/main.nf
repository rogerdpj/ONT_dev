process AUTOCYCLER {

    container "$params.autocycler.docker"

    publishDir "data/out/2-autocycler", mode: 'copy'

    input:
    tuple val(barcode_id), path(reads), val(genome_size_map), val (sample_code)

    output:
    path("autocycler_out/consensus_assembly.fasta"), emit: final_assembly
    tuple val(sample_code), path("autocycler_out/consensus_assembly.gfa"), emit: final_gfa


    script:

    """    
    echo "Running Autocycler for sample: ${reads}"
    
    # Step 1: Autocycler subsample

    autocycler subsample \
      --reads ${reads} \
      --out_dir subsampled_reads \
      --genome_size ${genome_size_map}
    
    # Step 2: Generating input assemblies
    
    mkdir assemblies
    for assembler in canu flye metamdbg miniasm necat nextdenovo raven; do
      for i in 01 02 03 04; do
        autocycler helper \$assembler --reads subsampled_reads/sample_\${i}.fastq --out_prefix assemblies/\${assembler}_\${i} --threads ${task.cpus} --genome_size ${genome_size_map}
      done
    done

    # Step 3: Autocycler compress and cluster

    autocycler compress --assemblies_dir assemblies --autocycler_dir autocycler_out
    autocycler cluster --autocycler_dir autocycler_out

    # Step 4: Autocycler trim and resolve

    for c in autocycler_out/clustering/qc_pass/cluster_*; do
      autocycler trim --cluster_dir \$c
      autocycler resolve --cluster_dir \$c
    done

    # Step 5: Autocycler combine

    autocycler combine \\
      --autocycler_dir autocycler_out \\
      --in_gfas autocycler_out/clustering/qc_pass/cluster_*/5_final.gfa

    """
}
