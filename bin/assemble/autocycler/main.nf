process AUTOCYCLER {
    tag "autocycler ${sample_code}"

    container "$params.autocycler.docker"

    publishDir "${params.outdir}/2-Assembly/1-Autocycler", mode: 'copy', saveAs: { filename ->
        if (filename.endsWith(".tsv")) {
            return "${sample_code}/metrics.tsv"
        } else {
            return null
        }
    }

    input:
    tuple val(barcode_id), path(reads), val(genome_size_map), val (sample_code)

    output:
    path("autocycler_out/consensus_assembly.fasta"), emit: final_assembly
    tuple val(sample_code), path("autocycler_out/consensus_assembly.gfa"), emit: final_gfa
    path("metrics.tsv"), emit: metrics

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
    for assembler in plassembler canu flye miniasm necat nextdenovo raven; do
      for i in 01 02 03 04; do
        autocycler helper \$assembler --reads subsampled_reads/sample_\${i}.fastq --out_prefix assemblies/\${assembler}_\${i} --genome_size ${genome_size_map}
      done
    done

    # Step 3: Autocycler compress and cluster
    RUST_BACKTRACE=1 \
    RAYON_NUM_THREADS=2 \
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

    # Step 6: Autocycler Table

    TABLE=metrics.tsv
    autocycler table > \$TABLE #Create the header
    autocycler table --autocycler_dir autocycler_out --name "${sample_code}" >> \$TABLE

    """
}
