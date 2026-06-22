nextflow.enable.dsl=2

log.info """\
              ONT - ASSEMBLY

            P A R A M E T E R S
==============================================
Configuration environment:
    Fastq directory:           $params.input
    Out directory:             $params.outdir
    Plasmid analysis:          $params.plasmid
""".stripIndent()


// MODULES

include { PREPARE_KRAKEN_DB                             }     from '../modules/kraken/db_set'

include { QC                                            }     from '../modules/qc/main'
include { TRIMMING                                      }     from '../modules/trimming/main'
include { KRAKEN_ONT;SEQTK_PRUNE                        }     from '../modules/kraken/main'
include { NANOCOMP                                      }     from '../modules/qc/nanocomp/main'

include { ASSEMBLY                                      }     from '../modules/assembly/flye/main'
include { POLISHING_ROUND                               }     from '../modules/polishing/main'
include { MEDAKA                                        }     from '../modules/assembly/medaka/main'
include { DNAAPLER                                      }     from '../modules/polishing/dnaapler/main'
include { WRAP                                          }     from '../modules/polishing/wrap/main'

include { BAKTA                                         }     from '../modules/annotation/bakta/main'

include { BUSCO                                         }     from '../modules/qc/busco/main'
include { QUAST                                         }     from '../modules/qc/quast/main'
include { MOSDEPTH                                      }     from '../modules/qc/mosdepth/main'
include { MULTIQC                                       }     from '../modules/qc/multiqc/main'

include { MLST                                          }     from '../modules/mlst/main'
include { AMR                                           }     from '../modules/AMR/abricate/main'
include { AMR_2                                         }     from '../modules/AMR/amrfinder/main'

include { PLASMID_SEARCH                                }     from '../modules/plasmid/main'

include { INTEGRATE                                     }     from '../modules/integrate/main'
include { COLLECT                                       }     from '../modules/collect/main'

// MAIN WORKFLOW

workflow assembly {
    def target_db_dir = file("${params.kraken_db_dir}/${params.db_select}")
    def db_check_file = file("${target_db_dir}/hash.k2d")

    def kraken_db_ch = Channel.empty()
    if ( db_check_file.exists() ) {
        log.info "Kraken2 database found locally! Skipping setup step."
        kraken_db_ch = Channel.value( target_db_dir )
    } else {
        log.info "Kraken2 database not found. Triggering download/build process..."
        kraken_db_ch = PREPARE_KRAKEN_DB().db_ready.first()
    }
    pre     = pre_process(kraken_db_ch)
    asm     = assembly_process(pre.reads)
    amr     = amr_process (asm.assembly)

    version_channels = [
        pre.versions,
        asm.versions,
        amr.versions
    ]
   
    if (params.plasmid) {
        plasmid     = workflow_plasmid(asm.assembly)
        version_channels << plasmid.versions
        
        integr = integration(
            amr.abricate_tuple,
            plasmid.plasmid_channel
        )
        integr.report.collect()

    }
    
    collect(version_channels, amr.mlst_channel, amr.abricate_channel)
}


// PREPROCESSING

workflow pre_process {
    take:
    kraken_db

    main:
    // Input discovery
    reads_raw = Channel
        .fromPath(params.input, type: 'dir', checkIfExists: true)
        .map { dir -> tuple(dir.baseName, dir) }
    
    // QC
    qc = QC(reads_raw)

    // Trimming
    genome_size_ch = Channel
        .fromPath(params.genome_size_file)
        .splitCsv(header: true)
        .map { row ->
            tuple(row.barcode, row.genome_size as int)
        }
    
    reads_with_target = qc.fastq_combine
        .join(genome_size_ch, by: 0)
        .map { barcode, fastq_file, genome_size ->
            def target_bases = Math.max(
                genome_size * params.target_coverage,
                50_000_000
            )
            tuple(barcode, fastq_file, target_bases)
        }

    trimmed = TRIMMING(reads_with_target)
    reads_trimmed = trimmed.reads_trimmed_gz

    // Kraken input
    kraken = KRAKEN_ONT(reads_trimmed, kraken_db)

    // Prunning
    pruning_input = reads_trimmed
        .join(kraken.keep_ids, by: 0)
        .map { sample, reads, ids ->
            tuple(sample, reads, ids)
        }

    pruned = SEQTK_PRUNE(pruning_input)
    reads_clean = pruned.pruned_reads
    
    // QC comparison
    raw_fastq = qc.fastq_combine.map { id, f -> tuple(id, "1_raw", f) }
    trimmed_fastq = reads_trimmed.map { id, f -> tuple(id, "2_trimmed", f) }
    clean_fastq = reads_clean.map { id, f -> tuple(id, "3_clean", f) }

    combined_stream = raw_fastq
        .mix(trimmed_fastq)
        .mix(clean_fastq)
        .map { id, stage, fastq_file -> tuple("${id}_${stage}", fastq_file) }

    nanocomp_input = combined_stream
        .toList()
        .map { all_pairs ->
            def sorted_pairs = all_pairs.sort { a, b -> a[0] <=> b[0] }
            def labels = sorted_pairs.collect { it[0] }
            def files  = sorted_pairs.collect { it[1] }
            return tuple("QC", labels, files)
        }

    nanocomp = NANOCOMP(nanocomp_input)

    emit:
        reads = reads_clean
        versions = qc.versions
            .mix(trimmed.versions)
            .mix(kraken.versions)
            .mix(pruned.versions)
            .mix(nanocomp.versions)

}

// ASSEMBLY + POLISHING + QC

workflow assembly_process {
    take:
    reads
        
    main:
    // Genome metadata
    genome_size = Channel
        .fromPath(params.genome_size_file)
        .splitCsv(header: true)
        .map { row ->
            tuple(row.barcode, row.genome_size as int, row.sample_code)
        }

    reads_with_size = reads
        .join(genome_size, by: 0)
        .map { id, read_file, size, sample ->
            tuple(id, read_file, size, sample)
        }

    // Assembly
    flye = ASSEMBLY(reads_with_size)

    // Coverage extraction
    coverage = flye.info_cov
        .map { sample, file ->
            def line = file.text.readLines()[1]
            def cov = line.tokenize('\t')[2] as int
            tuple(sample, cov)
        }

    flye_assembly = flye.assembly

    // Map reads by sample
    reads_by_sample_polish = reads_with_size
        .map { barcode, read_file, genome_size, sample ->
            tuple(sample, read_file)
        }

    reads_by_sample_medaka = reads_with_size
        .map { barcode, read_file, genome_size, sample ->
            tuple(sample, read_file)
        }

    reads_by_sample_mosdepth = reads_with_size
        .map { barcode, read_file, genome_size, sample ->
            tuple(sample, read_file)
        }

    // Polishing input
    flye_joined = reads_by_sample_polish
        .join(flye_assembly, by: 0)

    polishing_input = flye_joined
        .join(coverage, by: 0)
        .map { sample, read_file, assembly_fasta, cov ->
            def rounds = cov <= 14 ? 5 : 1
            tuple(sample, read_file, assembly_fasta, rounds)
        }
    
    (polished, polished_versions, polished_report) = POLISHING_ROUND(polishing_input)

    // Medaka
    medaka_input = reads_by_sample_medaka
        .join(polished, by: 0)
        .map { sample, read_file, fasta ->
            tuple(sample, read_file, fasta)
        }

    medaka = MEDAKA(medaka_input)

    // Final processing
    dna  = DNAAPLER(medaka.assembly_medaka)
    wrap = WRAP(dna.reoriented_assembly)

    // Annotation
    bakta = BAKTA(wrap.wrapped)

    // QC
    busco = BUSCO(wrap.wrapped)
    quast = QUAST(wrap.wrapped)

    mosdepth_input = reads_by_sample_mosdepth
        .join(wrap.wrapped, by: 0)
    mos = MOSDEPTH(mosdepth_input)


    multiqc_input = busco.results.map{ it[1] }
        .mix(quast.results.map{ it[1] })
        .mix(mos.summary.map{ it[1] })
        .mix(mos.dist.map{ it[1] })
        .collect()

    multiqc = MULTIQC(multiqc_input)


    emit:
        assembly = wrap.wrapped
        versions = flye.versions
            .mix(polished_versions)
            .mix(medaka.versions)
            .mix(dna.versions)
            .mix(wrap.versions)
            .mix(bakta.versions)
            .mix(busco.versions)
            .mix(quast.versions)
            .mix(mos.versions)
            .mix(multiqc.versions)

}

// AMR + MLST

workflow amr_process {
    
    take:
    assembly

    main:
    mlst = MLST(assembly)

    mlst_organism_ch = mlst.tab
        .map { sample_code, tab_file ->
            def line = tab_file.text.trim()
            def parts = line.tokenize() // splits by spaces/tabs
            def organism = parts.size() > 1 ? parts[1] : "default"
            return tuple(sample_code, organism)
        }
    
    amr_input = assembly.join(mlst_organism_ch, by: 0)

    amr = AMR(amr_input)
    amr_2 = AMR_2(assembly)
    

    emit:
    versions = amr.versions
        .mix(amr_2.versions)
        .mix(mlst.versions)
    
    mlst_channel = mlst.tab.map { sample_code, file -> file }
    abricate_channel = amr.abricate_report
    abricate_tuple = amr.abricate_tuple

}

// PLASMID ANALYSIS

workflow workflow_plasmid {
    take:
    assembly

    main:
    plasmid = PLASMID_SEARCH (assembly)

    emit:
    versions = plasmid.versions
    plasmid_channel = plasmid.contig_report
}

workflow integration {

    take:
    abricate_tuple
    plasmid_channel

    main:
    // Join both inputs by sample
    to_integrate = abricate_tuple
        .join(plasmid_channel, by: 0)

    integrated = INTEGRATE(to_integrate)

    // Return only files (not tuples)
    emit:
    report = integrated.report.map { sample_code, file -> file }
}

workflow collect {

    take:
    version_channels
    mlst_channel
    abricate_channel

    main:

    all_versions = Channel.empty()

    version_channels.each { ch ->
        all_versions = all_versions.mix(ch)
    }
    
    unique_versions = all_versions
        .unique { it.name }
        .toSortedList { a, b -> a.name <=> b.name }

    sorted_mlst = mlst_channel
        .toSortedList { a, b -> a.name <=> b.name }

    sorted_abricate = abricate_channel
        .toSortedList { a, b -> a.name <=> b.name }

    COLLECT(
        unique_versions,
        sorted_mlst,
        sorted_abricate
    )
}