process INTEGRATE {
    tag "CONTEXT: ${sample_code}"
    label 'env_integrate'
    
    publishDir "${params.outdir}/3-AMR/Integrated_reports", mode: 'copy'

    input:
    tuple val(sample_code), path(abricate_report), path(amrfinder_report), path(plasmid_report)

    output:
    tuple val(sample_code), path("${sample_code}_abricate_integrated.tsv"), emit: abricate
    tuple val(sample_code), path("${sample_code}_amrfinder_integrated.tsv"), emit: amrfinder

    script:
    """
    #!/usr/bin/env python3
    import pandas as pd

    # Load and clean plasmid report
    df_plasmid = pd.read_csv("${plasmid_report}", sep="\\t")
    df_plasmid["clean_contig"] = df_plasmid["contig_id"].str.split().str[0]
    
    plasmid_cols = ["clean_contig", "molecule_type", "rep_type(s)"]
    plasmid_cols = [c for c in plasmid_cols if c in df_plasmid.columns]
    df_plasmid = df_plasmid[plasmid_cols]

    # Abricate integration
    df_abricate = pd.read_csv("${abricate_report}", sep="\\t")
    

    if not df_abricate.empty and "SEQUENCE" in df_abricate.columns:

        abr = pd.merge(
            df_abricate,
            df_plasmid,
            left_on="SEQUENCE",
            right_on="clean_contig",
            how="left"
        )

        abr.drop(columns=["clean_contig"], inplace=True, errors="ignore")
        abr["molecule_type"] = abr["molecule_type"].fillna("unknown")

        # reorder columns
        move_cols = ["molecule_type", "rep_type(s)"]
        move_cols = [c for c in move_cols if c in abr.columns]

        cols = list(abr.columns)
        if "SEQUENCE" in cols:
            idx = cols.index("SEQUENCE")
            for c in move_cols:
                if c in cols:
                    cols.remove(c)
            cols = cols[:idx+1] + move_cols + cols[idx+1:]
            abr = abr[cols]

    else:
        abr = df_abricate

    abr.to_csv("${sample_code}_abricate_integrated.tsv", sep="\\t", index=False)


    # AMRFINDER INTEGRATION
    df_amr = pd.read_csv("${amrfinder_report}", sep="\\t")

    if not df_amr.empty and "Contig id" in df_amr.columns:

        amr = pd.merge(
            df_amr,
            df_plasmid,
            left_on="Contig id",
            right_on="clean_contig",
            how="left"
        )

        amr.drop(columns=["clean_contig"], inplace=True, errors="ignore")
        amr["molecule_type"] = amr["molecule_type"].fillna("unknown")

        # reorder columns
        move_cols = ["molecule_type", "rep_type(s)"]
        move_cols = [c for c in move_cols if c in amr.columns]

        cols = list(amr.columns)
        if "Contig id" in cols:
            idx = cols.index("Contig id")
            for c in move_cols:
                if c in cols:
                    cols.remove(c)
            cols = cols[:idx+1] + move_cols + cols[idx+1:]
            amr = amr[cols]

    else:
        amr = df_amr

    amr.to_csv("${sample_code}_amrfinder_integrated.tsv", sep="\\t", index=False)

    """
}