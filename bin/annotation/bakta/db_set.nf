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
    export HOME=\$PWD
    
    if [ -d "db-light" ]; then
        if [ ! -f "db-light/db.json" ]; then
             rm -rf db-light
        else
             exit 0
        fi
    fi

    # Download db light
    bakta_db download --type light --output db-light
    
    """
}
