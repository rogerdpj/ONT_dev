process INTEGRATE {
    tag "CONTEXT: ${sample_code}"
    label 'env_integrate'
    
    publishDir "${params.outdir}/3-AMR/Integrated_report", mode: 'copy'

    input:
    tuple val(sample_code), path(abricate_report), path(plasmid_report)

    output:
    tuple val(sample_code), path("${sample_code}_integrated_report.tsv"), emit: report

    script:
    """
    #!/usr/bin/env python3
    import pandas as pd

    # Load and clean plasmid report
    df_plasmid = pd.read_csv("${plasmid_report}", sep="\\t")
    df_plasmid["clean_contig"] = df_plasmid["contig_id"].str.split().str[0]

    # Load Abricate report
    df_abricate = pd.read_csv("${abricate_report}", sep="\\t")
    
    if not df_abricate.empty and "SEQUENCE" in df_abricate.columns:
        crossed = pd.merge(
            df_abricate,
            df_plasmid[["sample_id", "clean_contig", "molecule_type", "predicted_mobility", "rep_type(s)"]],
            left_on="SEQUENCE",
            right_on="clean_contig",
            how="left"
        )
        crossed["molecule_type"] = crossed["molecule_type"].fillna("unknown")
        if "clean_contig" in crossed.columns:
            crossed.drop(columns=["clean_contig"], inplace=True)

        plasmid_cols = ["molecule_type", "rep_type(s)"]
        plasmid_cols = [c for c in plasmid_cols if c in crossed.columns]

        cols = list(crossed.columns)

        if "SEQUENCE" in cols:
            idx = cols.index("SEQUENCE")

            for c in plasmid_cols:
                if c in cols:
                    cols.remove(c)

            new_cols = (
                cols[:idx + 1] +
                plasmid_cols +
                cols[idx + 1:]
            )

            crossed = crossed[new_cols]

    else:
        crossed = df_abricate

    crossed.to_csv("${sample_code}_integrated_report.tsv", sep="\\t", index=False)
    """
}