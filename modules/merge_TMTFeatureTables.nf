// Module: Build the dataset linked-feature table for feature-based TMT.
/**
 * Input: conflict-resolved dataset consensusXML and one TSV per fraction. Output: one TSV containing
 * every plex/fraction/channel row; linked feature IDs are reconciled with the final
 * consensusXML.
 */
process merge_TMTFeatureTables {
    container params.docker_image_pyopenms
    containerOptions params.project_script_mount_options

    publishDir "${params.final_output_dir}", mode: 'copy', pattern: '*.tsv'

    input:
        path(consensus)
        path(tables)

    output:
        path("${params.dataset_id}_LinkedFeatures.tsv")

    script:
    def inputs = tables instanceof List ? tables : [tables]
    """
    python ${projectDir}/src/MergeTMTFeatureTables.py \\
        --consensus-xml ${consensus} \\
        --inputs ${inputs.join(' ')} \\
        --output ${params.dataset_id}_LinkedFeatures.tsv
    """
}
