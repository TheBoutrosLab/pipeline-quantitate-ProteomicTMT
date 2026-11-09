// Module: Collect the feature-based linked maps from every fraction.
/**
 * Input: fraction consensusXMLs with identical plex/channel columns. Output: one
 * dataset consensusXML; the helper checks headers and preserves plex filenames.
 */
process merge_ConsensusXML_TMTFractions {
    container params.docker_image_pyopenms
    containerOptions params.project_script_mount_options

    publishDir "${params.final_output_dir}", mode: 'copy', pattern: '*.consensusXML'

    input:
    path(maps)

    output:
    path("${params.dataset_id}_FeatureBased.consensusXML")

    script:
    def inputs = maps instanceof List ? maps : [maps]
    """
    python ${projectDir}/src/MergeTMTFractionConsensus.py \\
        --inputs ${inputs.join(' ')} \\
        --output ${params.dataset_id}_FeatureBased.consensusXML
    """
}
