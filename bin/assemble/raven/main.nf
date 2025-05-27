process SUB_SAMPLE_3 {
  tag "Assemble with Raven - ${barcode_id}"
  cpus 24
  container 'quay.io/biocontainers/raven:1.8.1--he4480ba_0'

  input:
    tuple val(barcode_id), path(barcode_file), val(genome_size), val(sample_code)

  output:
    // Aquí defines un canal llamado `raven_fasta`
    tuple val(sample_code), path("raven_output_${sample_code}.fasta"), emit: raven_fasta

  script:
  """
    mkdir -p raven_output_${sample_code}

    raven ${barcode_file} \
      --threads ${task.cpus} \
      --min-unitig-size 1000 \
      --graphical-fragment-assembly raven_output_${sample_code}.gfa \
      > raven_output_${sample_code}/raw_assembly.fasta \
      2> raven_error.log

    if [[ ! -s raven_output_${sample_code}/raw_assembly.fasta ]]; then
      gfatools gfa2fa raven_output_${sample_code}.gfa \
        > raven_output_${sample_code}.fasta
    else
      mv raven_output_${sample_code}/raw_assembly.fasta \
         raven_output_${sample_code}.fasta
    fi
  """
}
