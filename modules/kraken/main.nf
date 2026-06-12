process KRAKEN_ONT {
  tag "Taxonomic classification of ${sample_id}"
  label 'env_kraken'

  cpus   { params.kraken_cpus ?: 4 }
  memory { params.kraken_mem  ?: '16 GB' }
  time '24h'
  stageInMode 'symlink'

  publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"
  publishDir "${params.outdir}/logs/kraken", mode: 'copy', pattern: "*.report.txt"
  publishDir "${params.outdir}/logs/kraken", mode: 'copy', pattern: "*.kraken.log"

  input:
  tuple val(sample_id), path(reads_sn) 
  path db_dir

  output:
  tuple val(sample_id), path("${sample_id}.kraken"),                emit: kraken_out
  tuple val(sample_id), path("${sample_id}.kraken.noise.clean.id"), emit: keep_ids
  path("${sample_id}.report.txt"),                                  emit: report
  path "${task.process}.version.txt",                                              emit: versions
  tuple val(sample_id), path("${sample_id}.kraken.log"),            emit: log

  script:
  """
  set -euo pipefail

  echo "kraken2\t\$(kraken2 --version 2>&1 | head -n 1)" > ${task.process}.version.txt
  
  for f in hash.k2d opts.k2d taxo.k2d; do
      [[ -r "${db_dir}/${params.db_select}/\$f" ]] || { 
          echo "Missing file: ${db_dir}/${params.db_select}/\$f"; 
          ls -lah "${db_dir}/${params.db_select}";
          exit 2; 
      }
  done

  kraken2 \
    --db "${db_dir}/${params.db_select}" \
    "${reads_sn}" \
    --threads ${task.cpus} \
    --gzip-compressed \
    --memory-mapping \
    ${ params.kraken2_extra_args ?: '' } \
    ${ params.kraken_confidence ? "--confidence ${params.kraken_confidence}" : "" } \
    --report "${sample_id}.report.txt" \
    > "${sample_id}.kraken" \
    2> "${sample_id}.kraken.log"

  awk '
  BEGIN{
    split("${params.kraken_deny_taxids ?: ''}", a, " ");
    for(i in a) deny[a[i]]=1;
  }
  { 
    status=\$1; rid=\$2; tax=\$3;
    if (status=="U") { print rid; next }
    if (!(tax in deny)) { print rid }
  }
  ' "${sample_id}.kraken" > "${sample_id}.kraken.noise.clean.id"
  """
}

process SEQTK_PRUNE {
  tag "Filtering contaminants of ${sample_id}"
  label 'env_seqtk'
  
  publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"
  publishDir "${params.outdir}/logs/seqtk", mode: 'copy', pattern: "*.log"


  input:
    tuple val(sample_id), path(reads_sn), path(keep_ids)
    
  output:
    tuple val(sample_id), path("${sample_id}.prune.clean.fastq.gz"), emit: pruned_reads
    path "${task.process}.version.txt", emit: versions
    tuple val(sample_id), path("${sample_id}.seqtk.log"), emit: log

  script:
  """
  set -euo pipefail
  
  echo "seqtk\t\$(seqtk --version 2>&1 | head -n 1)" > ${task.process}.version.txt

  seqtk subseq ${reads_sn} ${keep_ids} | gzip > ${sample_id}.prune.clean.fastq.gz \
  2> ${sample_id}.seqtk.log
  """
}