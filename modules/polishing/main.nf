process POLISHING_ROUND {
    tag "Polishing ${sample_code} for ${max_rounds} rounds"
    label 'env_polishing'
 
    publishDir "${params.outdir}/versions", mode: 'copy', pattern: "*version.txt"
    publishDir "${params.outdir}/logs/polishing", mode: 'copy', pattern: "polishing_report.txt"

    input:
    tuple val(sample_code), path(trimmed_reads), path(assembly_fasta), val(max_rounds)

    output:
    tuple val(sample_code), path("final_polished_${sample_code}.fasta"), emit: polished
    path "${task.process}.version.txt", emit: versions
    path "polishing_report.txt", emit: report

    script:

    """
    set -euo pipefail

    echo -e "minimap2\t\$(minimap2 --version 2>&1 | head -n 1)" > ${task.process}.version.txt
    echo -e "racon\t\$(racon --version 2>&1)" >> ${task.process}.version.txt

    echo "===== POLISHING REPORT =====" > polishing_report.txt
    echo -e "sample\t${sample_code}" >> polishing_report.txt
    echo -e "rounds\t${max_rounds}" >> polishing_report.txt
    echo -e "input_reads\t${trimmed_reads}" >> polishing_report.txt
    echo -e "initial_assembly\t${assembly_fasta}" >> polishing_report.txt
    echo "" >> polishing_report.txt

    input_fasta=${assembly_fasta}

    for round in {1..${max_rounds}}; do

        echo -e "round\t\${round}" >> polishing_report.txt

        aln_file="aln_round\${round}_${sample_code}.paf"
        output_fasta="racon_round\${round}_${sample_code}.fasta"

        # Step 1: Alignment
        minimap2 -x lr:hq \${input_fasta} ${trimmed_reads} -t ${task.cpus} > \${aln_file}

        identity=\$(awk '{sum+=\$10; len+=\$11} END {if(len>0) print sum/len; else print 0}' \${aln_file})
        echo -e "alignment_identity\t\${identity}" >> polishing_report.txt

        # Step 2: Polishing 
        racon ${trimmed_reads} \${aln_file} \${input_fasta} --threads ${task.cpus} > \${output_fasta}

        # Verify the output
        if [ ! -s \${output_fasta} ]; then
            echo "Error: \${output_fasta} was not generated. Exiting." >&2
            exit 1
        fi

        size=\$(grep -v ">" \${output_fasta} | wc -c)
        echo -e "assembly_size\t\${size}" >> polishing_report.txt
        echo "" >> polishing_report.txt

        # Update input fasta for the next round
        input_fasta=\${output_fasta}
    done

    # Rename the final file 
    mv \${input_fasta} final_polished_${sample_code}.fasta

    final_size=\$(grep -v ">" final_polished_${sample_code}.fasta | wc -c)
    
    echo "=== FINAL ===" >> polishing_report.txt
    echo -e "final_assembly_size\t\${final_size}" >> polishing_report.txt

    """
}