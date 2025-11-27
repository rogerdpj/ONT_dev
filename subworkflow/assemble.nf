/*
DSL2 channels
*/
nextflow.enable.dsl=2

log.info """\

WGS - P A R A M E T R E S
==============================================
Configuration environemnt:
    Out directory:             $params.outdir
    Fastq directory:           $params.input
    Reference directory:       $params.reference
"""
    .stripIndent()

//Call all the sub-work
include { PREPARE_KRAKEN_DB                             }     from '../bin/kraken/db_set'
include { QC                                            }     from '../bin/qc/main'
include { TRIMMING                                      }     from '../bin/trimming/main'
include { KRAKEN_ONT;SEQTK_PRUNE                        }     from '../bin/kraken/main'
include { NANOCOMP                                      }     from '../bin/qc/nanocomp/main'
include { SUB_SAMPLE_2 as ASSEMBLE                      }     from '../bin/assemble/fly/main'
include { POLISHING_ROUND                               }     from '../bin/polishing/main'
include { MEDAKA                                        }     from '../bin/assemble/medaka/main'
include { DNAAPLER                                      }     from '../bin/polishing/dnaapler_assemble'
include { WRAP                                          }     from '../bin/polishing/wrap_2'
include { PROKKA                                        }     from '../bin/annotation/prokka/main'
include { BAKTA                                         }     from '../bin/annotation/bakta/main_3'
include { AGT                                           }     from '../bin/annotation/main'
include { BUSCO                                         }     from '../bin/qc/busco/main'
include { QUAST                                         }     from '../bin/qc/quast/main'
include { MULTIQC                                       }     from '../bin/qc/multiqc/main'
include { AMR                                           }     from '../bin/AMR/abricate/main'
include { AMR_2                                         }     from '../bin/AMR/resfinder/main'
include { MLST                                          }     from '../bin/mlst/main'
include { BAKTA_SET_DB                                  }     from '../bin/annotation/bakta/db_set'
include { PLASMID_SEARCH                                }     from '../bin/plasmid/main'

workflow assemble {
    krakenprocess_output = workflow_kraken_process()
    preprocess_output = pre_process(krakenprocess_output.DB_CH)
    assambleprocess_output = assamble_process(preprocess_output.prune_reads_ch, krakenprocess_output.DB_BAKTA_CH)
    amrprocess_output = amr_process (assambleprocess_output.wrap_ch)
    if (params.plasmid) {
        plasmidprocess_output = workflow_plasmid(assambleprocess_output.wrap_ch)
    }
}

workflow workflow_kraken_process {
    db_ready_ch = PREPARE_KRAKEN_DB()
    DB_CH= db_ready_ch.db_ready
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

workflow assamble_process {
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

    fly_ch = ASSEMBLE(reads_with_size_ch)

//POLISHING PROCESS
//Porcesar el emit del assembly en fly para determinar numeros de polishing
coverage_ch = fly_ch.info_cov
    .map { sample_code, info_file -> 
        // Lee el archivo `assembly_info.txt` y extrae la cobertura
        def cov_value = info_file
            .text
            .split("\n")  // Divide en líneas
            .drop(1)      // Omite la cabecera
            .collect { line -> line.split("\t")[2] as int }[0]  // Extrae la columna 'cov.' (índice 2) y convierte a int
        tuple(sample_code, cov_value)
    }


// Creacion de channel que combina los input para el procesamiento de polishing en relacion al coverage obtneido en fly 
    sample_fixe = reads_with_size_ch.map { tupla ->
        def pathread = tupla [1]
        def sample_code = tupla [3]
        return tuple(sample_code, pathread)}

    polished_ch = sample_fixe
        .join(fly_ch.fly_assambly_tuple)
        .join(coverage_ch)
        .map { sample_code, trimmed_reads, assembly_fasta, cov_value -> 
            def max_rounds = (cov_value <= 14) ? 8 : 5 //asignacion de numero de polishing ( nªround each raund inclue: minimap + racon )
            tuple(sample_code, trimmed_reads, assembly_fasta, max_rounds)
        }

    polished_ch_final = POLISHING_ROUND(polished_ch)

    medaka_ch = sample_fixe
        .join(polished_ch_final)
        .map { sample_code, trimmed_reads, final_polishing_fasta ->
            tuple(sample_code, trimmed_reads, final_polishing_fasta)
        }
   
    medaka_consensum_ch= MEDAKA(medaka_ch)

    consensum_file_ch = medaka_consensum_ch.assemble_medaka

    dna_apler_ch = DNAAPLER(medaka_consensum_ch.assemble_medaka)

    wrap_ch = WRAP(dna_apler_ch.reoriented_assembly)

    prokka_ch = PROKKA (wrap_ch)

    bakta_ch = BAKTA (wrap_ch, DB_BAKTA_CH)

    agt_ch = prokka_ch.prokka_gff
            .join(bakta_ch.bakta_gff3)
            .join(wrap_ch.wrapped)

    AGT(agt_ch)

    busco_ch = BUSCO(medaka_consensum_ch.assemble_medaka)
    
    quast_ch = QUAST(medaka_consensum_ch.assemble_medaka)

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