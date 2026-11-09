// Module: Restore plex-specific measurements after feature linking.
/**
 * Input: one fraction-linked consensusXML and its per-run value sidecars. Output: an
 * annotated fraction consensusXML and a feature/channel TSV.
 */
process annotate_LinkedTMTMeasurements {
    container params.docker_image_pyopenms
    containerOptions params.project_script_mount_options
    publishDir "${params.intermediate_file_dir}/feature_based", mode: 'copy', enabled: params.save_intermediate_files, pattern: '*.feature-based-TMT.consensusXML'
    publishDir "${params.intermediate_file_dir}/feature_based", mode: 'copy', enabled: params.save_intermediate_files, pattern: '*.feature-based-TMT.tsv'
    input:
    tuple val(fraction), path(linked), path(values)
    output:
    tuple val(fraction), path("${fraction}.feature-based-TMT.consensusXML")
    tuple val(fraction), path("${fraction}.feature-based-TMT.tsv")
    script:
    def sidecars = values instanceof List ? values : [values]
    """
    python ${projectDir}/src/ExportLinkedTMTValues.py \\
        --linked-consensus-xml ${linked} --values ${sidecars.join(' ')} \\
        --fraction-id ${fraction} \\
        --output-tsv ${fraction}.feature-based-TMT.tsv \\
        --output-consensus-xml ${fraction}.feature-based-TMT.consensusXML
    """
}
