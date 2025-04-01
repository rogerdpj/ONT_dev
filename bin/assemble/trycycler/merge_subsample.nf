process MERGE_ASSEMBLE {
    tag "Merge assemble using Trycycler ${sample_code}"

    publishDir "${params.outdir}/6-merge_assemble", mode: 'copy'

    container "$params.trycyler.docker"

    input:
    tuple val(sample_code), val(barcode_id), path(barcodefile), val(genome_size), path(assembly_canu_file), path(fly_assambly_tuple), path(raven_aseembly_file)

    output:
    tuple val(sample_code), val(barcode_id), path("clustering_${barcode_id}_chromosome"), emit: chrom_clusters
    tuple val(sample_code), val(barcode_id), path("clustering_${barcode_id}_plasmid/cluster_*/1_contigs/*.fasta"), emit: plasmid_clusters

    script:

    """

    export GENOME_SIZE=${genome_size}

    # Verificar que los ensamblajes existen y no están vacíos
    if [[ ! -s ${assembly_canu_file} || ! -s ${fly_assambly_tuple} || ! -s ${raven_aseembly_file} ]]; then
        echo "ERROR: Uno o más archivos de ensamblaje están vacíos o no existen." >&2
        exit 1
    fi

    # Crear directorio de salida si no existe
    
    mkdir -p clustering_info_${barcode_id}

    # Paso 1: Crear clusters con Trycycler
    
    trycycler cluster \
        -a ${assembly_canu_file} \
           ${fly_assambly_tuple} \
           ${raven_aseembly_file} \
        -r ${barcodefile} \
        -o clustering_${barcode_id} \
        --threads 8 2>&1 | tee clustering_info_${barcode_id}/clustering_info.txt



    # Paso 2: Filtrar clusters automáticamente con el script externo para etiquetar
    #y reducir el numero de contings
    
    bash ${params.filterClustersScript} clustering_${barcode_id}
    
    """
}

/*

process RECONCILE_ASSEMBLE {
    tag "Reconcile assemblies for barcode ${barcode_id}"

    publishDir "${params.outdir}/7-reconcile_assemble", mode: 'copy'

    container "$params.trycyler.docker"

    input:
    tuple val(sample_code), val(barcode_id), path(contigs_dir) from merge_assemblies_trycycler

    output:
    path "${contigs_dir}/7_final_consensus.fasta", emit: final_consensus

    script:
    """

    # Ejecutar Trycycler reconcile en el directorio de contigs ya limpio
    trycycler reconcile --cluster_dir ${contigs_dir} 2>&1 | tee ${contigs_dir}/reconcile.log

    # Mover el consenso final a la salida
    mv ${contigs_dir}/7_final_consensus.fasta .
    """
}



    # Paso 3: Reconciliar clusters buenos

    find clustering_${barcode_id} -maxdepth 1 -type d -name "cluster_*" > valid_clusters.txt
    
    for cluster_dir in clustering_${barcode_id}/cluster_*; do
    echo "🔄 Reconciliando cluster: $cluster_dir"
    trycycler reconcile -d "$cluster_dir" -r "${barcodefile}" --threads 8 || {
        echo "❌ Error en la reconciliación del cluster $cluster_dir. Revisa los logs antes de continuar."
        exit 1
    }
    done
    

    # Paso 5: Comparar identidad entre contigs si hay al menos dos contigs

    for cluster_dir in clustering_${barcode_id}/cluster_*; do
        mapfile -t contig_files < <(find "\$cluster_dir/1_contigs/" -name "*.fasta" 2>/dev/null)

        if [[ "\${#contig_files[@]}" -ge 2 ]]; then
            echo "Comparando identidad entre contigs en \$cluster_dir"
            trycycler dotplot -c "\$cluster_dir"
        else
            echo "No hay suficientes contigs para comparación en \$cluster_dir"
        fi
    done





    # Paso 4: Generar alineamientos múltiples
    trycycler msa \
        --clusters_dir clustering_${barcode_id}

    # Paso 5: Particionar lecturas en clusters
    trycycler partition \
        --clusters_dir clustering_${barcode_id} \
        --reads ${barcodefile}

    # Paso 6: Construir consenso final
    trycycler consensus \
        --clusters_dir clustering_${barcode_id}
*/   