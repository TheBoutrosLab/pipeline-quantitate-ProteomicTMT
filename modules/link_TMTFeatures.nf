include { getToolArgs } from './common'

// Module: Link comparable MS1 features across plexes within one fraction.
/**
 * Input: feature-based TMT consensusXMLs for a fraction. Output: a linked consensusXML
 * retaining the reporter-channel subelements.
 */
process link_TMTFeatures {
    container params.docker_image_openms
    publishDir "${params.intermediate_file_dir}/feature_based", mode: 'copy', enabled: params.save_intermediate_files, pattern: '*.consensusXML'

    input:
        tuple val(fraction), path(maps)

    output:
        tuple val(fraction), path("${fraction}.linked.raw.consensusXML")

    script:
    def inputs = maps instanceof List ? maps : [maps]
    if (inputs.size() == 1) {
        return "cp ${inputs[0]} ${fraction}.linked.raw.consensusXML"
    }
    def program_options = params.FeatureLinkerUnlabeledQT ?: [:]
    def flag_options = ['algorithm:use_identifications',
        'algorithm:ignore_charge'] as Set
    def extra_args = getToolArgs(program_options, flag_options)
    """
    FeatureLinkerUnlabeledQT -in ${inputs.join(' ')} \\
        -out ${fraction}.linked.raw.consensusXML -keep_subelements \\
        -threads ${task.cpus} ${extra_args}
    """
}
