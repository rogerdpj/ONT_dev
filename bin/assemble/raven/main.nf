process SUB_SAMPLE_3 {
  tag "Assemble with Raven - ${barcode_id}"
  input:
    tuple val(barcode_id), path(barcode_file), val(genome_size), val(sample_code)
  output:
    tuple val(sample_code), path("raven_output_${sample_code}.fasta"), emit: raven_aseembly_file

  script:
  """
    # Doble check all the inputs are corrects and no empty
    if [[ ! -s "${barcode_file}" ]]; then
        echo "❌ ERROR: El archivo de lectura '${barcode_file}' está vacío o no existe." >&2
        exit 1
    fi

    # unzip just in case is neccesary
    if [[ "${barcode_file}" == *.gz ]]; then
        gunzip -c "${barcode_file}" > input_reads.fastq
    else
        cp "${barcode_file}" input_reads.fastq
    fi

    mkdir -p raven_output_${sample_code}

    # Comman run RAVEN
    raven input_reads.fastq --threads ${task.cpus} \
      > raven_output_${sample_code}/${sample_code}_assembly.fasta 2> raven_error.log

    mv raven_output_${sample_code}/${sample_code}_assembly.fasta \
       raven_output_${sample_code}.fasta
  """
}