process AMR {
    tag "ABRICATE for ${sample_code}"
    label 'env_abricate'
    
    publishDir "${params.outdir}/3-AMR/ABRICATE", mode: 'copy', pattern: "*.tsv"
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*.version.txt"

    input:
    tuple val(sample_code), path(assembly_file)
    val organism

    output:
    path("${sample_code}_abricate_report.tsv"), emit: abricate_report
    path "${task.process}.version.txt", emit: versions

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

    def dbEnvBlock = params.abricate_db ?
        "export ABRICATE_DB='${params.abricate_db}'" :
        ""

    """
    set -euo pipefail

    echo -e "abricate\t\$(abricate --version 2>&1 | head -n 1)" > ${task.process}.version.txt

    ${dbEnvBlock}

    DBS=(${dbs_str})

    echo -e "FILE\\tSEQUENCE\\tSTART\\tEND\\tSTRAND\\tGENE\\tCOVERAGE\\tCOVERAGE_MAP\\tGAPS\\t%COVERAGE\\t%IDENTITY\\tDATABASE\\tACCESSION\\tPRODUCT\\tRESISTANCE" > ${sample_code}_abricate_report.tsv

    for db in \${DBS[@]}; do
        echo "[AMR] Running ABRICATE with database: \$db"
        abricate --db \$db ${assembly_file} --noheader >> ${sample_code}_abricate_report.tsv
    done
    """
}