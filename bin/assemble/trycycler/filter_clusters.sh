#!/bin/bash

if [[ -z "$1" ]]; then
    echo "❌ ERROR: Debes proporcionar el directorio de clusters."
    echo "Uso: bash filter_clusters.sh clustering_barcode20"
    exit 1
fi

clustering_dir="$1"
info_dir=$(echo "$clustering_dir" | sed 's/clustering_/clustering_info_/')
log_file="${info_dir}/clustering_info.txt"
output_file="${clustering_dir}/filtered_clusters_report.txt"
chromosome_list="${clustering_dir}/clusters_chromosome.txt"
plasmid_list="${clustering_dir}/clusters_plasmid.txt"

# Parámetros de filtrado
genome_size=${GENOME_SIZE:-4000000}
genome_min_size=$((genome_size * 80 / 100))
genome_max_size=$((genome_size * 120 / 100))
min_coverage=20
plasmid_max_size=200000
plasmid_min_depth=50

# Encabezados
echo -e "Cluster\tContig\tSize_bp\tDepth_x\tTipo" > "$output_file"
> "$chromosome_list"
> "$plasmid_list"

# Diccionarios
declare -A contig_sizes
declare -A contig_depths

# Leer el archivo clustering_info.txt
while IFS= read -r line; do
    if [[ "$line" =~ ([A-Z]_tig[0-9]+|B_contig_[0-9]+|C_Utg[0-9]+):[[:space:]]+([0-9,]+)\ bp,[[:space:]]+([0-9]+\.[0-9]+)x ]]; then
        contig_name="${BASH_REMATCH[1]}"
        contig_size="${BASH_REMATCH[2]//,/}"
        contig_depth="${BASH_REMATCH[3]}"
        contig_sizes["$contig_name"]=$contig_size
        contig_depths["$contig_name"]=${contig_depth%.*}
    fi
done < "$log_file"

declare -A cluster_types

# Clasificación
for cluster_dir in "${clustering_dir}"/cluster_*; do
    cluster_name=$(basename "$cluster_dir")
    contig_files=("$cluster_dir/1_contigs/"*.fasta)

    [[ ! -f "${contig_files[0]}" ]] && continue

    for file in "${contig_files[@]}"; do
        contig_name=$(basename "$file" .fasta)
        contig_size=${contig_sizes["$contig_name"]}
        contig_depth=${contig_depths["$contig_name"]}

        if [[ -z "$contig_size" || -z "$contig_depth" ]]; then
            tipo="RECHAZADO"
        elif [[ "$contig_size" -ge "$genome_min_size" && "$contig_size" -le "$genome_max_size" && "$contig_depth" -ge "$min_coverage" ]]; then
            tipo="CROMOSOMA"
            cluster_types["$cluster_dir"]="CROMOSOMA"
        elif [[ "$contig_size" -le "$plasmid_max_size" && "$contig_depth" -ge "$plasmid_min_depth" ]]; then
            tipo="PLÁSMIDO"
            cluster_types["$cluster_dir"]="PLÁSMIDO"
        else
            tipo="RECHAZADO"
        fi

        echo -e "$cluster_name\t$contig_name\t$contig_size\t$contig_depth\t$tipo" >> "$output_file"
    done
done

# Guardar listas por tipo
for cluster in "${!cluster_types[@]}"; do
    tipo=${cluster_types["$cluster"]}
    if [[ "$tipo" == "CROMOSOMA" ]]; then
        echo "$cluster" >> "$chromosome_list"
    elif [[ "$tipo" == "PLÁSMIDO" ]]; then
        echo "$cluster" >> "$plasmid_list"
    fi
done

# Copiar clusters a carpetas separadas
mkdir -p "${clustering_dir}_chromosome"
mkdir -p "${clustering_dir}_plasmid"

while IFS= read -r cluster; do
    cp -r "$cluster" "${clustering_dir}_chromosome/"
done < "$chromosome_list"

while IFS= read -r cluster; do
    cp -r "$cluster" "${clustering_dir}_plasmid/"
done < "$plasmid_list"

echo "✅ Clasificación completada:"
echo " - Contigs: $output_file"
echo " - Chromosome clusters → ${clustering_dir}_chromosome/"
echo " - Plasmid clusters    → ${clustering_dir}_plasmid/"