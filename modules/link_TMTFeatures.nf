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
    """
    FeatureLinkerUnlabeledQT -in ${inputs.join(' ')} \\
        -out ${fraction}.linked.raw.consensusXML -keep_subelements \\
        -algorithm:use_identifications ${params.feature_linker_use_identifications} \\
        -algorithm:distance_RT:max_difference ${params.feature_linker_rt_tolerance} \\
        -algorithm:distance_MZ:max_difference ${params.feature_linker_mz_tolerance_ppm} \\
        -algorithm:distance_MZ:unit ppm -threads ${task.cpus}
    """
}
