process BAKTA_SET_DB {
    tag "bakta_DB_light"
    
    container {
        workflow.containerEngine == 'singularity' ?
            "docker://${params.bakta_db.docker}" :
            params.bakta_db.docker
    }

    output:
    path("db-light/db-light"), emit: db_bakta_dir

    script:
    """
    mkdir -p ${params.bakta_db_dir}
    cd ${params.bakta_db_dir}

    export HOME=\$PWD

    # Si ya está descargada, no hacemos nada
    if [ -f "db-light/db-light/bakta.db" ]; then
        echo "[BAKTA_SET_DB] Usando BD existente en \$(pwd)/db-light/db-light"
        exit 0
    fi

    # Descarga + intento de update de AMRFinderPlus
    set +e
    bakta_db download --type light --output db-light
    EXIT=\$?
    set -e

    # Si bakta_db falla pero bakta.db existe, asumimos que sólo ha caído amrfinder_update
    if [ \$EXIT -ne 0 ]; then
        if [ -f "db-light/db-light/bakta.db" ]; then
            >&2 echo "[BAKTA_SET_DB] WARNING: bakta_db salió con código \$EXIT; asumo fallo de AMRFinderPlus pero la BD de Bakta está OK."
            exit 0
        else
            >&2 echo "[BAKTA_SET_DB] ERROR: bakta_db falló (código \$EXIT) y no hay bakta.db; aborto."
            exit \$EXIT
        fi
    fi
    """
}