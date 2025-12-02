nextflow.enable.dsl = 2

if (params.help) {
    printHelp()
    exit 0
}

checkInputParams()

reference = file("${params.reference}")

log.info """\

WGS ONT - N F   P I P E L I N E 
==============================================
Configuration environment:
    Genome size file:          $params.genome_size_file
    Mode:                      $params.mode
    profile:                   $workflow.profile
"""
    .stripIndent()

// Subworkflows 

if (params.mode == 'assemble') {
    include { assemble } from "$projectDir/subworkflow/assemble" 
} else if (params.mode == 'hybrid') {
    include { hybrid } from "$projectDir/subworkflow/hybrid"
} else if (params.mode == 'hybrid_vc') {
    include { hybrid_vc} from "$projectDir/subworkflow/hybrid_vc"
} else {
    error "Invalid mode: ${params.mode}. Please specify 'assamble' ,'hybrid' or 'hybrid_vc'"
}

// Definir el workflow principal
workflow {
    if (params.mode == 'assemble') {
        assemble()  
    } else if (params.mode == 'hybrid') {
        hybrid()
    } else if (params.mode == 'hybrid_vc') {
        hybrid_vc()
    }
}


////////////////////////////////////////////////////////////////////////////////
// FUNCTIONS                                                                  //
////////////////////////////////////////////////////////////////////////////////

def printHelp() {
    def readmeFile = file("${projectDir}/README.md")
    def printSection = false

    if (readmeFile.exists()) {
        log.info "\n"
        readmeFile.eachLine { line ->
            // Start printing when we hit the Usage header
            if (line.contains("Usage: nextflow run main.nf [--help] [--mode VAR] [--genome_size_file VAR] [--input VAR] [--short_inputs VAR] [--outdir VAR] [--organism VAR] [--min_length VAR] [--min_mean_q VAR] [--keep_percent VAR] [--plasmid] [--bakta_db_define VAR] [--db_select VAR] [--abricate_db VAR] [-w VAR] [-profile VAR]")) {
                printSection = true
            }
            // Stop printing when we hit the next major header (Output)
            if (line.contains("## Output")) {
                printSection = false
            }
            
            // Print the line if we are inside the section
            if (printSection) {
                log.info line
            }
        }
        log.info "\n"
    } else {
        log.warn "README.md not found in ${projectDir}"
    }
}

def checkInputParams() {
    // Check required parameters and display error messages
    boolean fatal_error = false

    if (!params.input) {
        log.warn("You need to provide a valid input directory with --input")
        fatal_error = true
    }
    if (!params.genome_size_file) {
        log.warn("You need to provide a valid genome size file with --genome_size_file")
        fatal_error = true
    }
    if (!params.mode) {
        log.warn("You need to provide a valid mode with --mode (assemble, hybrid)")
        fatal_error = true
    }
    if( params.mode == 'hybrid' && !params.short_reads ) {
        log.warn "You need to provide a valid short read data with --short_reads when using hybrid mode"
        fatal_error = true
    }
    if( !['docker','singularity','conda'].contains( workflow.profile ) ) {
        log.warn "You need to provide a valid profile with -profile (docker, singularity, conda)"
        fatal_error = true
    }
    if (fatal_error) {
        error "Missing one or more required parameters"
    }
}