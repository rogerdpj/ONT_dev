process KRAKEN_ONT {
  tag "Taxonomic classification of ${sample_id}"
  label 'kraken_run'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
      "docker://${params.kraken.docker}" :
      params.kraken.docker }"
  
  cpus   { params.kraken_cpus ?: 4 }
  memory { params.kraken_mem  ?: '16 GB' }
  time '24h'
  stageInMode 'symlink'

  input:
  tuple val(sample_id), path(reads_sn), path (db_dir)

  output:
  tuple val(sample_id), path("${sample_id}.kraken"),                emit: kraken_dir
  tuple val(sample_id), path("${sample_id}.kraken.noise.clean.id"), emit: keep_ids
  path("${sample_id}.report.txt"),                                  emit: report

  script:
  """
  test -r "${db_dir}/hash.k2d" -a -r "${db_dir}/opts.k2d" -a -r "${db_dir}/taxo.k2d" \
    || { echo "DB incompleta en ${db_dir}"; ls -lah "${db_dir}"; exit 2; }

  # ONT: un solo FASTQ, sin --paired
  kraken2 \
    --db "${db_dir}" \
    "${reads_sn}" \
    --threads ${task.cpus} \
    --gzip-compressed \
    --memory-mapping \
    ${ params.kraken2_extra_args ?: '' } \
    ${ params.kraken_confidence ? "--confidence ${params.kraken_confidence}" : "" } \
    --report "${sample_id}.report.txt" \
    > "${sample_id}.kraken"

  cat > ids.awk << 'AWK'
  BEGIN{
    split("9443 9606 9605 9604 9598 9593 9601 9526 9483 314295 40674", a, " ");
    for(i in a) deny[a[i]]=1;
  }
  { status=\$1; rid=\$2; tax=\$3;
    if (status=="U") { print rid; next }
    if (!(tax in deny)) { print rid }
  }
  AWK

  awk -f ids.awk "${sample_id}.kraken" > "${sample_id}.kraken.noise.clean.id"
  """
}


process SEQTK_PRUNE {
  tag "Filtering contaminants of ${sample_id}"
  label 'seqtk_prune'
  
  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
      "docker://${params.short_wgs.docker}" :
      params.short_wgs.docker }"

  input:
    tuple val(sample_id), path(reads_sn), path(keep_ids)
    
  output:
    tuple val(sample_id), path("${sample_id}.prune.clean.fastq.gz"), emit: pruned_reads

  script:
  """
  seqtk subseq ${reads_sn} ${keep_ids} | gzip > ${sample_id}.prune.clean.fastq.gz
  
  """
}