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
