include { getToolArgs } from './common'

// Module: Find integrated MS1 features for one plex/fraction run.
/**
 * Input: mzML and its run-specific idXML. Output: FFId featureXML with peptide
 * identifications.
 */
process find_MS1Features {
    container params.docker_image_openms
    publishDir "${params.intermediate_file_dir}/${plex}/FFId", mode: 'copy', enabled: params.save_intermediate_files, pattern: '*.featureXML'

    input:
    tuple val(plex), path(mzml), path(idxml)

    output:
    tuple val(plex), path("${plex}.featureXML")

    script:
    def program_options = params.FeatureFinderIdentification ?: [:]
    def flag_options = ['svm:no_selection', 'svm:no_shrinking',
        'quantify_decoys', 'EMGScoring:init_mom', 'model:unweighted_fit',
        'model:no_imputation', 'model:each_trace'] as Set
    def extra_args = getToolArgs(program_options, flag_options)
    """
    FeatureFinderIdentification \\
        -in ${mzml} \\
        -id ${idxml} \\
        -out ${plex}.featureXML \\
        -threads ${task.cpus} ${extra_args}
    """
}
