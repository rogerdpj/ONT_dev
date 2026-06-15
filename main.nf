/*
  ============================================================
    N F   P I P E L I N E - ONT_BACTERIAL_ANALYSIS

  Oxford Nanopore (ONT) Sequencing Pipeline - Nextflow
  ============================================================

  Author:        Jimmy Lucas and Roger de Pedro Jové
  Description:   A scalable Nextflow pipeline for automated WGS analysis, 
                 optimized for Oxford Nanopore and hybrid ONT–Illumina 
                 assemblies in clinical microbiology research.
  Version:       2.0.0

    ============================================================
*/

nextflow.enable.dsl = 2

if (params.help) {
    printHelp()
    exit 0
}

checkInputParams()

// Logging 

log.info """\

   ___  _   _ _____   ____    _    ____ _____ _____ ____  ___    _    _      
  / _ \\| \\ | |_   _| | __ )  / \\  / ___|_   _| ____|  _ \\|_ _|  / \\  | |     
 | | | |  \\| | | |   |  _ \\ / _ \\| |     | | | _|  | |_) || |  / _ \\ | |     
 | |_| | |\\  | | |   | |_) / ___ \\ |___  | | | |___|  _ < | | / ___ \\| |___  
  \\___/|_| \\_| |_|   |____/_/ __\\_\\____|_|_|_|_____|_| \\_\\___/_/   \\_\\_____| 
       / \\  | \\ | |  / \\  | | \\ \\ / / ___|_ _/ ___|                          
      / _ \\ |  \\| | / _ \\ | |  \\ V /\\___ \\| |\\___ \\                          
     / ___ \\| |\\  |/ ___ \\| |___| |  ___) | | ___) |                         
    /_/   \\_\\_| \\_/_/   \\_\\_____|_| |____/___|____/


N F   P I P E L I N E - ONT_BACTERIAL_ANALYSIS 
==============================================
Configuration environment:
    Pipeline mode:             ${params.mode}
    Genome size file:          ${params.genome_size_file}
    Profile:                   ${workflow.profile}
""".stripIndent()


log.info """\
Run summary:
    Input:                     ${params.input}
    Output:                    ${params.outdir}
    Short reads:               ${params.short_inputs ?: 'N/A'}
    Plasmid analysis:          ${params.plasmid}
    Organism:                  ${params.organism}
""".stripIndent()


// Subworkflow import

include { assembly }   from "$projectDir/subworkflow/assembly"
//include { hybrid }     from "$projectDir/subworkflow/hybrid"

// Main workflow

workflow {

    switch (params.mode) {

        case 'assembly':
            assembly()
            break
        case 'hybrid':
            hybrid()
            break
        default:
            error "Invalid mode: ${params.mode}. Valid options: assembly and hybrid"
    }
}

// Functions 


def printHelp() {
    def readmeFile = file("${projectDir}/README.md")
    def printSection = false

    if (readmeFile.exists()) {
        log.info "\n"
        readmeFile.eachLine { line ->
            if (line.contains("Usage:")) {
                printSection = true
            }
            if (line.contains("## Output")) {
                printSection = false
            }
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

    boolean fatal_error = false

    if (!params.input) {
        log.warn("You need to provide a valid input directory with --input")
        fatal_error = true
    }

    if (!params.genome_size_file) {
        log.warn("Missing --genome_size_file")
        fatal_error = true
    } else if (!file(params.genome_size_file).exists()) {
        log.warn("Genome size file does not exist: ${params.genome_size_file}")
        fatal_error = true
    }

    if (!params.mode) {
        log.warn("Missing --mode (assembly | hybrid)")
        fatal_error = true
    }

    if (params.mode == 'hybrid' && !params.short_inputs) {
        log.warn("Hybrid mode requires --short_inputs")
        fatal_error = true
    }

    def valid_profiles = ['docker','singularity','conda']
    if (!workflow.profile || !valid_profiles.any { workflow.profile.tokenize(',').contains(it) }) {
        log.warn("Invalid profile: use docker, singularity or conda")
        fatal_error = true
    }

    if (fatal_error) {
        error "Missing or invalid parameters"
    }
}
