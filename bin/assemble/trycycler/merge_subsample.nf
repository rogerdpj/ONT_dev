process MERGE_ASSEMBLE {
    tag "Merge assemble using Trycycler ${barcode_id}"

    publishDir "${params.outdir}/6-merge_assemble", mode: 'copy'

    container "$params.trycyler.docker"

    input:
    tuple val(sample_code), val(barcode_id), path(barcodefile), val(genome_size), path(assembly_canu_file), path(fly_assambly_tuple), path(raven_aseembly_file)

    output:
    path "clustering_${barcode_id}/", emit: merge_assemblies_trycycler

    script:

    """

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

    # Paso 2: Filtrar clusters automáticamente con el script externo 
    
    export GENOME_SIZE=${genome_size}
    ${params.filterClustersScript} clustering_${barcode_id}

    """
}

/*

   


    # Paso 3: Reconciliar clusters buenos (Corrección: solo una vez)
    # Verificar si hay clusters válidos

    cluster_count=\$(find clustering_${barcode_id}/ -type d -name "cluster_*" | wc -l)

    if [[ "\$cluster_count" -eq 0 ]]; then
        echo "No se encontraron clusters válidos. Abortando." >&2
        exit 1
    fi

    for cluster_dir in clustering_${barcode_id}/cluster_*; do
        trycycler reconcile --cluster_dir \$cluster_dir --reads ${barcodefile} || {
            echo "Error en la reconciliación del cluster \$cluster_dir. Cluster descartado."
            rm -rf "\$cluster_dir"
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