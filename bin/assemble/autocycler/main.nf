process AUTOCYCLER {

    container "$params.autocycler.docker"

    publishDir "results/autocycler", mode: 'copy'

    input:
    tuple val(barcode_id), path(trimmed_reads), val(genome_size_map), val (sample_code)

    output:
    path("consensus_assembly.fasta"), emit: final_assembly

    script:
    """
    echo ">>> Procesando muestra: $sample_code"

    mkdir -p $sample_code && cd $sample_code

    # Paso 1: Subsampleo
    autocycler subsample \\
      --reads ${trimmed_reads} \\
      --out_dir subsampled \\
      --genome_size ${genome_size_map}

    # Paso 2: Ensamblaje con múltiples herramientas
    mkdir assemblies
    for asm in canu flye miniasm necat nextdenovo raven; do
      for i in 01 02 03 04; do
        \$asm.sh subsampled/sample_\$i.fastq* assemblies/\${asm}_\$i ${task.cpus} ${genome_size_map}
      done
    done

    # Paso 3: Compress + Cluster
    autocycler compress --input assemblies --autocycler_dir .
    autocycler cluster --autocycler_dir .

    # Paso 4: Trim + Resolve
    for c in clustering/qc_pass/cluster_*; do
      autocycler trim --cluster_dir \$c
      autocycler resolve --cluster_dir \$c
    done

    # Paso 5: Combine
    autocycler combine \\
      --autocycler_dir . \\
      --input clustering/qc_pass/cluster_*/5_final.gfa

    # Copiar ensamblado final al directorio de salida
    cp consensus_assembly.fasta ../consensus_assembly.fasta
    """
}
