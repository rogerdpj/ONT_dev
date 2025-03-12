#!/bin/bash

# 📌 Directorio del clustering
clustering_dir=$1
info_dir="${clustering_dir/clustering_/clustering_info_}"  
log_file="${info_dir}/clustering_info.txt"

# 📌 Parámetros de filtrado
genome_size=${GENOME_SIZE:-4000000}  # 4 Mbp por defecto
genome_min_size=$((genome_size * 80 / 100))
genome_max_size=$((genome_size * 120 / 100))
min_coverage=20  # Cobertura mínima aceptada

# 📌 Archivo de salida
output_file="${clustering_dir}/filtered_clusters_report.txt"
echo -e "Cluster\tContigs\tLongest_Contig\tMean_Depth\tStatus" > "$output_file"

echo "📌 Filtrando clusters usando información de: $log_file"
echo "📌 Límites: ${genome_min_size} - ${genome_max_size} bp y cobertura mínima ${min_coverage}x"

# 📝 Verificar si el archivo de clustering existe
if [[ ! -f "$log_file" ]]; then
    echo "❌ ERROR: No se encontró el archivo de clustering: $log_file"
    exit 1
fi

# 📌 Extraer información de tamaños y coberturas
declare -A contig_sizes
declare -A contig_depths
declare -A cluster_contigs

while read -r line; do
    if [[ "$line" =~ ([A-Z]_tig[0-9]+|B_contig_[0-9]+|C_Utg[0-9]+):[[:space:]]+([0-9]+)\ bp,[[:space:]]+([0-9]+\.[0-9]+)x ]]; then
        contig_name="${BASH_REMATCH[1]}"
        contig_size="${BASH_REMATCH[2]}"
        contig_depth="${BASH_REMATCH[3]}"

        contig_sizes["$contig_name"]=$contig_size
        contig_depths["$contig_name"]=$contig_depth
    fi
done < "$log_file"

# 📌 Iterar sobre los clusters y calcular métricas
for cluster_dir in "${clustering_dir}/cluster_"*; do
    cluster_name=$(basename "$cluster_dir")

    contig_files=("$cluster_dir/1_contigs/"*.fasta)
    if [[ ! -f "${contig_files[0]}" ]]; then
        echo -e "$cluster_dir\t0\t0\t0\tIGNORADO" >> "$output_file"
        echo "❌ Archivo FASTA no encontrado en $cluster_dir. Cluster ignorado."
        continue
    fi

    # 📌 Calcular número de contigs, tamaño del más largo y cobertura media
    contig_count=0
    longest_contig=0
    total_depth=0
    for file in "${contig_files[@]}"; do
        contig_name=$(basename "$file" .fasta)
        contig_size=${contig_sizes["$contig_name"]}
        contig_depth=${contig_depths["$contig_name"]}

        if [[ -n "$contig_size" && -n "$contig_depth" ]]; then
            ((contig_count++))
            total_depth=$(echo "$total_depth + $contig_depth" | bc)
            if [[ "$contig_size" -gt "$longest_contig" ]]; then
                longest_contig=$contig_size
            fi
        fi
    done

    # 📌 Calcular la profundidad media del cluster
    mean_depth=0
    if [[ "$contig_count" -gt 0 ]]; then
        mean_depth=$(echo "scale=2; $total_depth / $contig_count" | bc)
    fi

    # 📌 Evaluar si el cluster debe ser retenido
    if [[ "$longest_contig" -ge "$genome_min_size" && "$longest_contig" -le "$genome_max_size" && "$mean_depth" -ge "$min_coverage" && "$contig_count" -le 10 ]]; then
        echo -e "$cluster_dir\t$contig_count\t$longest_contig\t$mean_depth\tACEPTADO" >> "$output_file"
        echo "✅ Cluster $cluster_dir ACEPTADO."
    else
        echo -e "$cluster_dir\t$contig_count\t$longest_contig\t$mean_depth\tRECHAZADO" >> "$output_file"
        echo "❌ Cluster $cluster_dir RECHAZADO por criterios de tamaño/cobertura."
        rm -rf "$cluster_dir"
    fi
done

echo "📄 Reporte de clusters generado en $output_file"