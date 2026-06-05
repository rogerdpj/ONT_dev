process AMR {
    tag "ABRICATE search for ${sample_code}"
    label 'abricate_tool'
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "docker://${params.abricate.docker}" :
        params.abricate.docker }"

    publishDir "${params.outdir}/3-AMR/ABRICATE", mode: 'copy'

    input:
    tuple val(sample_code), path(assembly_file)
    val organism

    output:
    path("${sample_code}_combined_abricate_report.tsv"), emit: abricate_report

    script:

    // Convert organism name to lowercase and trim whitespace
    def organism_lc = organism.toLowerCase().trim()

    // Map databases by organism
    def db_map = [
        "escherichia coli":        ["ecoli_vf", "resfinder", "plasmidfinder", "card"],
        "klebsiella pneumoniae":   ["resfinder", "plasmidfinder", "card", "argannot"],
        "default":                 ["vfdb_full", "resfinder", "plasmidfinder", "card"]
    ]

    // Get databases for this organism or use default
    def dbs = db_map.get(organism_lc, db_map["default"])
    def dbs_str = dbs.collect { "\"${it}\"" }.join(" ")
    def usingContainer = (workflow.containerEngine != null)

    def dbEnvBlock
    if (usingContainer) {
        dbEnvBlock = params.abricate_db ?
            "export ABRICATE_DB='${params.abricate_db}'" :
            ""
    } else {
        dbEnvBlock = params.abricate_db ?
            "export ABRICATE_DB='${params.abricate_db}'" :
            "echo '[AMR] INFO: ABRICATE_DB is not defined. " +
            "If you are using -profile conda, pass --abricate_db /path/to/db " +
            "to specify where the Abricate databases are located.' >&2"
}

    """
    set -euo pipefail

    ${dbEnvBlock}

    DBS=(${dbs_str})

    echo -e "FILE\\tSEQUENCE\\tSTART\\tEND\\tSTRAND\\tGENE\\tCOVERAGE\\tCOVERAGE_MAP\\tGAPS\\t%COVERAGE\\t%IDENTITY\\tDATABASE\\tACCESSION\\tPRODUCT\\tRESISTANCE" > ${sample_code}_combined_abricate_report.tsv

    for db in \${DBS[@]}; do
        echo "[AMR] Running ABRICATE with database: \$db"
        abricate --db \$db ${assembly_file} --noheader >> ${sample_code}_combined_abricate_report.tsv
    done

    """
}