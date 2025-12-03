/*
DSL2 channels
*/
nextflow.enable.dsl=2

log.info """\

           ONT - HYBRID ASSEMBLY

            P A R A M E T E R S
==============================================
Configuration environemnt:
    ONT fastq directory:            $params.input
    Illumina fastq directory:       $params.short_reads
    Out directory:                  $params.outdir
    Plasmid analysis:               $params.plasmid
    Organism:                       $params.organism
"""
    .stripIndent()

//Call all the sub-work

include { PREPARE_KRAKEN_DB                           }     from '../bin/kraken/db_set'
include { QC                                          }     from '../bin/qc/main'
include { TRIMMING                                    }     from '../bin/trimming/main'
include { KRAKEN_ONT;SEQTK_PRUNE                      }     from '../bin/kraken/main'
include { BAKTA_SET_DB                                }     from '../bin/annotation/bakta/db_set'
include { AUTOCYCLER                                  }     from '../bin/assemble/autocycler/main'
include { DNAAPLER                                    }     from '../bin/assemble/autocycler/dnaapler'
    /*
include { MSA                                         }     from '../bin/assemble/trycycler/msa'
include { PARTITION                                   }     from '../bin/assemble/trycycler/partition'
include { CONSENSUS                                   }     from '../bin/assemble/trycycler/consensus'
include { MOB_SUITE                                   }     from '../bin/plasmid/mob/main'
*/
include { FASTQC_QUALITY as FASTQC_QUALITY_ORIGINAL   }     from '../bin/qc/fastqc/main'
include { TRIMMING as SHORT_TRIMMING                  }     from '../bin/trimming/short_trimming'
include { FASTQC_QUALITY as FASTQC_QUALITY_FINAL      }     from '../bin/qc/fastqc/main'
include { MULTIQC_FASTQ                               }     from '../bin/qc/multiqc/main_2'
include { ALIGN_SHORT_READS;FILTER_ALIGNMENTS;POLISH  }     from '../bin/polishing/main_2'
include { WRAP                                        }     from '../bin/polishing/wrap'
include { QUAST                                       }     from '../bin/qc/quast/main'
include { BUSCO                                       }     from '../bin/qc/busco/main'
include { MULTIQC                                     }     from '../bin/qc/multiqc/main'
include { AMR                                         }     from '../bin/AMR/abricate/main'
include { AMR_2                                       }     from '../bin/AMR/resfinder/main'
include { PROKKA                                      }     from '../bin/annotation/prokka/main'
include { BAKTA                                       }     from '../bin/annotation/bakta/main_3'
include { AGAT                                         }     from '../bin/annotation/main'
include { PLASMID_SEARCH                              }     from '../bin/plasmid/main'

/*


include { POLISHING_1                                 }     from '../bin/assemble/main'
include { CONSENSUM                                   }     from '../bin/assemble/main'
include { POLISHING_2                                 }     from '../bin/assemble/main'
include { QUAST                                       }     from '../bin/qc/quast/main'
include { PROKKA                                      }     from '../bin/anotations/prokka/main'
include { BAKTA                                       }     from '../bin/anotations/bakta/main'
include { BUILD_INDEX_1                               }     from '../bin/bowtie/index/main_bwa'
include { BUILD_INDEX as PERSONAL_GENOME_INDEX        }     from '../bin/bowtie/index/main'
include { PERSONAL_GENOME_MAPPING                     }     from '../bin/bowtie/mapping/main'
include { MARKDUPLICATE                               }     from '../bin/gatk/picard/markduplicate/main'
include { ADDORREPLACE                                }     from '../bin/gatk/picard/addorreplace/main'
include { HAPLOTYPECALLER                             }     from '../bin/gatk/haplotype/main'
include { GENOTYPE as GENOTYPE_ANALYSIS               }     from '../bin/gatk/genotype/main'
include { ALIGN as NORMALICE_WILDTYPE                 }     from '../bin/gatk/Filter/align'
include { FILTER_VARIANTS as FILTER_VARIANTS_PARAM    }     from '../bin/gatk/Filter/main'
include { DECOMPRESS_VCF                              }     from '../bin/snpeff/main_2'
include { SNPEFF                                      }     from '../bin/snpeff/main'
include { AMR as POST_ANALYSIS_ABRICATE               }     from '../bin/AMR/abricate/main'
include { AMR_2 as POST_ANALYSIS_AMRFINDER            }     from '../bin/AMR/AMRFinder/main'
*/




workflow hybrid {
    krakenprocess_output = workflow_kraken_process()
    preprocess_output = pre_process(krakenprocess_output.DB_CH)
    assambleprocess_output = assamble_process(preprocess_output.prune_reads_ch)
    post_analysis_output = post_analysis(assambleprocess_output.dnaapler_ch, krakenprocess_output.DB_BAKTA_CH)
    if (params.plasmid) {
        plasmidprocess_output = workflow_plasmid(post_analysis_output.wrap_ch)
    }
   /* 
    vcprocess_output = workflow_vc()
    amrprocess_output = workflow_amr( preprocess_output.contigs_ch)
    */
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
    trimming_ch = TRIMMING(qc_ch.fastq_combine)
    trimming_files_ch = trimming_ch.barcodefile_compress

    //KRAKEN
    READS_DB_CH = trimming_files_ch.combine(DB_CH)
                .map { sample_id, reads_se, db_dir ->
                tuple (sample_id, reads_se, db_dir)
    }
    
    kraken_ch = KRAKEN_ONT (READS_DB_CH)

    //PRUNNING
    fastq_prunning_ch = trimming_files_ch.join(kraken_ch.keep_ids).map {
        sample_id,reads_sn, keep_ids ->
        tuple (sample_id, reads_sn, keep_ids)
    }
    
    prune_ch = SEQTK_PRUNE(fastq_prunning_ch)
    prune_reads_ch = prune_ch.pruned_reads
    

    emit:
    trimming_files_ch
    prune_reads_ch
    
}

workflow assamble_process {
    
    take:
    prune_reads_ch
    
    main:
    
    genome_size_ch = Channel
                        .fromPath(params.genome_size_file)
                        .splitCsv(header: true)
                        .map { row -> tuple(row.barcode, row.genome_size as int, row.sample_code) }


    reads_with_size_ch = prune_reads_ch.join(genome_size_ch)
    .map { barcode_id, barcode_file, genome_size, sample_code ->
        tuple(barcode_id, barcode_file, genome_size, sample_code)
    }
    
    autocycler_ch = AUTOCYCLER(reads_with_size_ch)

    dnaapler_all_ch = DNAAPLER(autocycler_ch.final_gfa)
    dnaapler_ch = dnaapler_all_ch.reoriented_assembly


/*    
    auticycler_ch = SUB_SAMPLE(trimming_files_ch, genome_size_map)
    collect_subsample_ch = COMBINE_SUBSAMPLED_READS(subsample_trycycler_ch)

    genome_size_ch = Channel
                        .fromPath(params.genome_size_file)
                        .splitCsv(header: true)
                        .map { row -> tuple(row.barcode, row.genome_size as int, row.sample_code) }

    
    reads_with_size_ch = collect_subsample_ch.join(genome_size_ch)
    .map { barcode_id, barcode_file, genome_size, sample_code ->
        tuple(barcode_id, barcode_file, genome_size, sample_code)
    }

    reads_with_size_ch.view()

    //Canu assemble
    sub_sample_1_canu_ch = SUB_SAMPLE_1(reads_with_size_ch)
        
    //Fly assemble
    sub_sample_2_fly_ch = SUB_SAMPLE_2(reads_with_size_ch)

    //Raven assemble
    sub_sample_3_raven_ch = SUB_SAMPLE_3(reads_with_size_ch)


    reads_for_try_ch = reads_with_size_ch.map { barcode_id, barcodefile, genome_size, sample_code -> 
    tuple(sample_code, barcode_id, barcodefile, genome_size)}

    
    trycyler_input_ch = reads_for_try_ch
        .join(sub_sample_1_canu_ch.assembly_canu_file)
        .join(sub_sample_2_fly_ch.fly_assambly_tuple)
        .join(sub_sample_3_raven_ch.raven_aseembly_file)

    trycyler_input_ch.view()
    
    trycycler_ch = MERGE_ASSEMBLE(trycyler_input_ch)

    merge_cluster001_ch = trycycler_ch.chrom_clusters.map { sample_code, barcode_id, cluster_dir ->
        def cluster001_path = cluster_dir.resolve('cluster_001')
        tuple(sample_code, barcode_id, cluster001_path)
    }

    reconcile_ch = RECONCILE_ASSEMBLE(merge_cluster001_ch, reads_for_try_ch)
    
    msa_ch = MSA(reconcile_ch.reconciled_dir)

    partition_ch = PARTITION(msa_ch.msa_dir, trimming_files_ch)

    consensus_ch = CONSENSUS(partition_ch.partition_dir)

    plasmid_process_ch = MOB_SUITE(trycycler_ch.plasmid_clusters)
*/

    emit:
    dnaapler_ch
    
}


workflow post_analysis {
    
    take:
    dnaapler_ch
    DB_BAKTA_CH

    main:
    // Canal de lecturas
    read_ch = Channel.fromFilePairs(params.short_reads, size: 2)
   
    fastqc_ch_original= FASTQC_QUALITY_ORIGINAL(read_ch.map{it -> it[1]})

    // Trimming de las lecturas
    trimmed_read_ch = SHORT_TRIMMING(read_ch)
    fq_gz_reads_ch = trimmed_read_ch.trimmed_reads

    //Final Quality control after trimming
    fastq_ch_after = FASTQC_QUALITY_FINAL(fq_gz_reads_ch.map{it -> it[1]})

    //MULTIQC
    multiqc_ch = MULTIQC_FASTQ(fastqc_ch_original.qc_zip.collect(), fastq_ch_after.qc_zip.collect())


    aligned_bam_ch = ALIGN_SHORT_READS(dnaapler_ch,fq_gz_reads_ch)

    filtered_sam_ch = FILTER_ALIGNMENTS(aligned_bam_ch.aligned_sam1,aligned_bam_ch.aligned_sam2)

    polishing_ch = POLISH (dnaapler_ch,filtered_sam_ch)

    wrap_ch = WRAP(polishing_ch)


    quast_ch = QUAST(wrap_ch)
    busco_ch = BUSCO(wrap_ch)

    multiqc_ch = MULTIQC(busco_ch.map{i -> i[1]}.collect(), quast_ch.map{i -> i[1]}.collect())

    AMR(wrap_ch, params.organism)
    AMR_2(wrap_ch)

    prokka_annotation_ch = PROKKA(wrap_ch)
    bakta_annotation_ch = BAKTA(wrap_ch, DB_BAKTA_CH)

    agt_ch = prokka_annotation_ch.prokka_gff
            .join(bakta_annotation_ch.bakta_gff3)
            .join(wrap_ch.polished_rewrapped)

    AGAT(agt_ch)

    emit:
    wrap_ch
    
}

workflow workflow_plasmid {
    take:
    wrap_ch

    main:
    
    //PLASMID SEARCH

    plasmid_search_ch = PLASMID_SEARCH (wrap_ch)

}


////////////////////////////////////////////////////////////////////////////////
//                                 FUNCTIONS                                  //
////////////////////////////////////////////////////////////////////////////////

def checkInputParams() {
    // Check required parameters and display error messages
    boolean fatal_error = false
    if ( ! params.input) {
        log.warn("You need to provide a fastqDir (--fastqDir) or a bamDir (--bamDir)")
        fatal_error = true
    }
}