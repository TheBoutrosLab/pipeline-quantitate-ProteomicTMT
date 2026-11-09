// Module: Collect scan-based reporter maps from separate TMT plexes.
/**
 * Input: one identified consensusXML per plex. Output: one dataset consensusXML with
 * each plex appended as distinct columns.
 */
process merge_ConsensusXML_TMTPlexes {
    container params.docker_image_openms
    publishDir "${params.final_output_dir}", mode: 'copy', pattern: '*.consensusXML'

    input:
        path(maps)

    output:
        path("${params.dataset_id}_ScanBased.consensusXML")

    script:
    def inputs = maps instanceof List ? maps : [maps]
    if (inputs.size() == 1) {
        return "cp ${inputs[0]} ${params.dataset_id}_ScanBased.consensusXML"
    }
    """
    FileMerger \\
        -in ${inputs.join(' ')} \\
        -out ${params.dataset_id}_ScanBased.consensusXML \\
        -append_method append_cols \\
        -threads ${task.cpus}
    """
}
