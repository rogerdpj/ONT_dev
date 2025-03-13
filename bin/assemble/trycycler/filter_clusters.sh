#!/bin/bash

# 📌 Verificar que se proporciona el directorio de clusters como argumento
if [[ -z "$1" ]]; then
    echo "❌ ERROR: Debes proporcionar el directorio de clusters."
    echo "Uso: bash filter_clusters_debug.sh clustering_barcode20"
    exit 1
fi

# 📌 Definir los directorios y archivos
clustering_dir="$1"
info_dir=$(echo "$clustering_dir" | sed 's/clustering_/clustering_info_/')
log_file="${info_dir}/clustering_info.txt"
output_file="${clustering_dir}/filtered_clusters_report.txt"

# 📌 Verificar que el archivo de información de clustering existe
if [[ ! -f "$log_file" ]]; then
    echo "❌ ERROR: No se encontró el archivo de información: $log_file"
    exit 1
fi

# 📌 Parámetros de filtrado
genome_size=${GENOME_SIZE:-4000000}  
genome_min_size=$((genome_size * 80 / 100))
genome_max_size=$((genome_size * 120 / 100))
min_coverage=20  

# 📌 Crear archivo de salida con encabezado
echo -e "Cluster\tContig\tSize_bp\tDepth_x\tStatus" > "$output_file"

echo "📌 Filtrando clusters usando información de: $log_file"
echo "📌 Límites: ${genome_min_size} - ${genome_max_size} bp y cobertura mínima ${min_coverage}x"

# 📌 Extraer información de contigs
declare -A contig_sizes
declare -A contig_depths

echo "🔍 Leyendo archivo clustering_info.txt desde: $log_file"

while IFS= read -r line; do
    if [[ "$line" =~ ([A-Z]_tig[0-9]+|B_contig_[0-9]+|C_Utg[0-9]+):[[:space:]]+([0-9,]+)\ bp,[[:space:]]+([0-9]+\.[0-9]+)x ]]; then
        contig_name="${BASH_REMATCH[1]}"
        contig_size="${BASH_REMATCH[2]//,/}"  # Elimina comas en números grandes
        contig_depth="${BASH_REMATCH[3]}"

        contig_sizes["$contig_name"]=$contig_size
        contig_depths["$contig_name"]=${contig_depth%.*}  # Elimina decimales para comparar en Bash

        echo "✅ Contig encontrado: $contig_name | Tamaño: $contig_size bp | Cobertura: ${contig_depths["$contig_name"]}x"
    fi
done < "$log_file"

echo "📌 Contigs procesados: ${!contig_sizes[@]}"
echo "📌 Profundidades almacenadas: ${contig_depths[@]}"

# 📌 Iterar sobre los clusters y procesar los contigs
for cluster_dir in "${clustering_dir}/cluster_"*; do
    cluster_name=$(basename "$cluster_dir")
    contig_files=("$cluster_dir/1_contigs/"*.fasta)

    if [[ ! -f "${contig_files[0]}" ]]; then
        echo "❌ No se encontraron archivos de contigs en $cluster_dir."
        continue
    fi

    echo "🔎 Cluster encontrado: $cluster_name"
    for file in "${contig_files[@]}"; do
        contig_name=$(basename "$file" .fasta)

        contig_size=${contig_sizes["$contig_name"]}
        contig_depth=${contig_depths["$contig_name"]}

        if [[ -z "$contig_size" || -z "$contig_depth" ]]; then
            echo "⚠️ No se encontró información para $contig_name en clustering_info.txt"
            continue
        fi

        echo "📊 Contig en cluster: $cluster_name | $contig_name | ${contig_size} bp | ${contig_depth}x"

        # 📌 Evaluar si el contig debe ser retenido
        if [[ "$contig_size" -ge "$genome_min_size" && "$contig_size" -le "$genome_max_size" && "$contig_depth" -ge "$min_coverage" ]]; then
            status="ACEPTADO"
        else
            status="RECHAZADO"
        fi

        # 📌 Guardar en el archivo de salida
        echo -e "$cluster_name\t$contig_name\t$contig_size\t$contig_depth\t$status" >> "$output_file"
    done
done

echo "📄 Reporte de contigs guardado en: $output_file"

# 📌 🗑️ Eliminar clusters rechazados
echo "🗑️ Eliminando clusters rechazados..."
declare -A rejected_clusters

while IFS=$'\t' read -r cluster contig size depth status; do
    if [[ "$status" == "RECHAZADO" ]]; then
        rejected_clusters["$cluster"]=1
    fi
done < "$output_file"

for cluster in "${!rejected_clusters[@]}"; do
    echo "❌ Eliminando $cluster..."
    rm -rf "${clustering_dir}/${cluster}"
done

echo "✅ Proceso de filtrado y eliminación completado."
