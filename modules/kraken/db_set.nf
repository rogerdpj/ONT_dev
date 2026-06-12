process PREPARE_KRAKEN_DB {
  tag "${params.db_select ?: 'db_16GB'}"
  label 'env_kraken_db'

  cpus 2
  memory '4 GB'
  time '24h'

  output:
  path 'kraken_db', emit: db_ready

  script:

  """

  export DB_DIR="/kraken2-db"
  export DB_SELECT='${params.db_select}'

  mkdir -p "\$DB_DIR"

  
  if [ -f "\$DB_DIR/\$DB_SELECT/hash.k2d" ]; then
      echo "Kraken DB already exists → skipping download"
  else
      echo "Kraken DB not found → downloading"
      kraken2-entrypoint.sh prepare-db "\$DB_SELECT"
  fi

  ${ params.db_url ? "export DB_URL='${params.db_url}'" : ":" }
  ${ params.db_url_checksum ? "export DB_URL_CHECKSUM='${params.db_url_checksum}'" : ":" }
  
  mkdir -p kraken_db
  ln -s /kraken2-db kraken_db

  chmod -R a+rX "\$DB_DIR" || true
  
  """
}