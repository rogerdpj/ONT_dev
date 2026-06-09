nextflow.enable.dsl=2

log.info """\
              ONT - ASSEMBLY

            P A R A M E T E R S
==============================================
Configuration environemnt:
Configuration environment:
    Fastq directory:           $params.input
    Out directory:             $params.outdir
    Plasmid analysis:          $params.plasmid
    Organism:                  $params.organism
""".stripIndent()

include { PREPARE_KRAKEN_DB                             }     from '../modules/kraken/db_set'
include { BAKTA_SET_DB                                  }     from '../modules/annotation/bakta/db_set'
include { QC                                            }     from '../modules/qc/main'
include { TRIMMING                                      }     from '../modules/trimming/main'
include { KRAKEN_ONT;SEQTK_PRUNE                        }     from '../modules/kraken/main'
include { NANOCOMP                                      }     from '../modules/qc/nanocomp/main'
include { SUB_SAMPLE_2 as ASSEMBLY                      }     from '../modules/assembly/flye/main'
include { POLISHING_ROUND                               }     from '../modules/polishing/main'
include { MEDAKA                                        }     from '../modules/assembly/medaka/main'
include { DNAAPLER                                      }     from '../modules/polishing/dnaapler_assembly'
include { WRAP                                          }     from '../modules/polishing/wrap_2'
include { PROKKA                                        }     from '../modules/annotation/prokka/main'
include { BAKTA                                         }     from '../modules/annotation/bakta/main_3'
include { ENRICHMENT_ANNOTATION                         }     from '../modules/annotation/main_2'
include { BUSCO                                         }     from '../modules/qc/busco/main'
include { QUAST                                         }     from '../modules/qc/quast/main'
include { MULTIQC                                       }     from '../modules/qc/multiqc/main'
include { AMR                                           }     from '../modules/AMR/abricate/main'
include { AMR_2                                         }     from '../modules/AMR/resfinder/main'
include { MLST                                          }     from '../modules/mlst/main'
include { PLASMID_SEARCH                                }     from '../modules/plasmid/main'

workflow assembly {
    krakenprocess_output = workflow_kraken_process()
    preprocess_output = pre_process(krakenprocess_output.DB_CH)
    assemblyprocess_output = assembly_process(preprocess_output.prune_reads_ch, krakenprocess_output.DB_BAKTA_CH)
    amrprocess_output = amr_process (assemblyprocess_output.wrap_ch)
    if (params.plasmid) {
        plasmidprocess_output = workflow_plasmid(assemblyprocess_output.wrap_ch)
    }
}

workflow workflow_kraken_process {
    //KRAKEN2_DB SETTING
    db_ready_ch = PREPARE_KRAKEN_DB()
    DB_CH= db_ready_ch.db_ready
    //BAKTA DB SETTING
    db_bakta_ready_ch = BAKTA_SET_DB()
    DB_BAKTA_CH = db_bakta_ready_ch.db_bakta_dir

    emit:
    DB_CH
    DB_BAKTA_CH
}

workflow pre_process {
    take:
    DB_CH

    main:
    barcode_dir_ch = channel.fromPath(params.input, type: 'dir').map{barcode_dir -> tuple(barcode_dir.baseName, barcode_dir)}
    qc_ch = QC(barcode_dir_ch)
    trimming_before_ch = TRIMMING(qc_ch.fastq_combine)
    trimming_ch = trimming_before_ch.barcodefile_gz
    trimming_ch_2 = trimming_before_ch.barcodefile_compress
    pre_data_qc = qc_ch.fastq_combine

    //KRAKEN
    READS_DB_CH = trimming_ch_2.combine(DB_CH)
                .map { sample_id, reads_se, db_dir ->
                tuple (sample_id, reads_se, db_dir)
    }
    
    kraken_ch = KRAKEN_ONT (READS_DB_CH)

    //PRUNNING
    fastq_prunning_ch = trimming_ch_2.join(kraken_ch.keep_ids).map {
        sample_id,reads_sn, keep_ids ->
        tuple (sample_id, reads_sn, keep_ids)
    }
    
    prune_ch = SEQTK_PRUNE(fastq_prunning_ch)
    prune_reads_ch = prune_ch.pruned_reads
    
    nocomp_ch = NANOCOMP(pre_data_qc.map{i -> i[1]}.collect(), prune_reads_ch.map{i -> i[1]}.collect())

    emit:
    prune_reads_ch
    
}

workflow assembly_process {
    take:
    prune_reads_ch
    DB_BAKTA_CH
        
    main:


    genome_size_ch = Channel
                        .fromPath(params.genome_size_file)
                        .splitCsv(header: true)
                        .map { row -> tuple(row.barcode, row.genome_size as int, row.sample_code) }

    reads_with_size_ch = prune_reads_ch.join(genome_size_ch)
        .map { barcode_id, barcode_file, genome_size, sample_code ->
            tuple(barcode_id, barcode_file, genome_size, sample_code)
        }

    flye_ch = ASSEMBLY(reads_with_size_ch)

//POLISHING PROCESS
//Porcesar el emit del assembly en flye para determinar numeros de polishing
coverage_ch = flye_ch.info_cov
    .map { sample_code, info_file -> 
        // Lee el archivo `assembly_info.txt` y extrae la cobertura
        def cov_value = info_file
            .text
            .split("\n")  // Divide en líneas
            .drop(1)      // Omite la cabecera
            .collect { line -> line.split("\t")[2] as int }[0]  // Extrae la columna 'cov.' (índice 2) y convierte a int
        tuple(sample_code, cov_value)
    // POLISHING PROCESS
    // Extract coverage from the assembly_info.txt file to determine the number of polishing rounds
    coverage_ch = flye_ch.info_cov
        .map { sample_code, info_file -> 
            // Read assembly_info.txt and extract the 'cov.' column (index 2)
            def cov_value = info_file
                .text
                .split("\n")
                .drop(1)
                .collect { line -> line.split("\t")[2] as int }[0]
            tuple(sample_code, cov_value)
        }

    // Create a channel mapping sample_code to reads for joining with assembly results
    reads_by_sample_ch = reads_with_size_ch.map { barcode_id, barcode_file, genome_size, sample_code ->
        tuple(sample_code, barcode_file)
    }


// Creacion de channel que combina los input para el procesamiento de polishing en relacion al coverage obtneido en flye 
    sample_fixe = reads_with_size_ch.map { tupla ->
        def pathread = tupla [1]
        def sample_code = tupla [3]
        return tuple(sample_code, pathread)}

    polished_ch = sample_fixe
    // Combine reads, assembly, and coverage to determine polishing rounds
    polished_ch = reads_by_sample_ch
        .join(flye_ch.flye_assembly_tuple)
        .join(coverage_ch)
        .map { sample_code, trimmed_reads, assembly_fasta, cov_value -> 
            def max_rounds = (cov_value <= 14) ? 8 : 5 //asignacion de numero de polishing ( nªround each raund inclue: minimap + racon )
            // Assign polishing rounds based on coverage:
            // Low coverage (<=14x) gets 8 rounds; higher coverage gets 5 rounds.
            def max_rounds = (cov_value <= 14) ? 8 : 5 
            tuple(sample_code, trimmed_reads, assembly_fasta, max_rounds)
        }

    polished_ch_final = POLISHING_ROUND(polished_ch)

    medaka_ch = sample_fixe
        .join(polished_ch_final)
        .map { sample_code, trimmed_reads, final_polishing_fasta ->
            tuple(sample_code, trimmed_reads, final_polishing_fasta)
        }
   
    medaka_consensus_ch= MEDAKA(medaka_ch)

    dna_apler_ch = DNAAPLER(medaka_consensus_ch.assembly_medaka)

    wrap_ch = WRAP(dna_apler_ch.reoriented_assembly)

    prokka_ch = PROKKA (wrap_ch)

    bakta_ch = BAKTA (wrap_ch, DB_BAKTA_CH)

    agt_ch = prokka_ch.prokka_gff
            .join(bakta_ch.bakta_gff3)
            .join(wrap_ch.wrapped)

    ENRICHMENT_ANNOTATION(agt_ch)

    busco_ch = BUSCO(medaka_consensus_ch.assembly_medaka)
    
    quast_ch = QUAST(medaka_consensus_ch.assembly_medaka)

    //MULTIQC Directory for analysis

    multiqc_ch = MULTIQC( busco_ch.map{i -> i[1]}.collect(), quast_ch.map{i -> i[1]}.collect())

    emit:
    wrap_ch

}

workflow amr_process {

    take:

    wrap_ch

    main:

    amr_ch = AMR(wrap_ch, params.organism)
    amr_2_ch = AMR_2(wrap_ch)
    mlst_ch = MLST(wrap_ch)

}

workflow workflow_plasmid {
    take:
    wrap_ch

    main:
    
    //PLASMID SEARCH

    plasmid_search_ch = PLASMID_SEARCH (wrap_ch)

}