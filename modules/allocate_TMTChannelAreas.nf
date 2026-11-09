// Module: Allocate each identified MS1 feature area among its TMT reporter channels.
/**
 * Input: aligned FFId features and identified reporter scans for one run. Output: a
 * labeled consensusXML and value sidecar; QC and scan assignments are optional
 * intermediate files.
 */
process allocate_TMTChannelAreas {
    container params.docker_image_pyopenms
    containerOptions params.project_script_mount_options
    publishDir "${params.intermediate_file_dir}/${run_key}/feature_tmt", mode: 'copy', enabled: params.save_intermediate_files, pattern: '*.consensusXML'
    publishDir "${params.intermediate_file_dir}/${run_key}/feature_tmt", mode: 'copy', enabled: params.save_intermediate_files, pattern: '*.tsv'
    input:
    tuple val(run_key), path(feature), path(reporters), val(plex_id)
    output:
    tuple val(run_key), path("${run_key}.feature-tmt.consensusXML")
    tuple val(run_key), path("${run_key}.feature-tmt-values.tsv")
    script:
    """
    python ${projectDir}/src/BuildFeatureBasedTMTConsensus.py \\
        --feature-xml ${feature} --reporter-consensus-xml ${reporters} \\
        --output-consensus-xml ${run_key}.feature-tmt.consensusXML \\
        --qc-tsv ${run_key}.feature-tmt-qc.tsv \\
        --assignment-tsv ${run_key}.feature-tmt-scan-assignment.tsv \\
        --values-tsv ${run_key}.feature-tmt-values.tsv --plex-id ${plex_id}
    """
}
