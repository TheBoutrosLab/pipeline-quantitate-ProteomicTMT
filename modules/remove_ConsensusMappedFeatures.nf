
process remove_ConsensusMappedFeatures {
    container params.docker_image_pyopenms
    containerOptions params.project_script_mount_options

    publishDir "${params.intermediate_file_dir}/${plex}/${task.process.replace(':', '/')}",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: "*.consensusXML"

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        tuple val(plex), path(input_consensus)

    output:
        tuple val(plex), path(output_consensus)
        file ".command.*"

    script:
    output_consensus = "${plex}_unmapped.consensusXML"
    """
    python ${projectDir}/src/ConsensusIDRemover.py \\
        --input-path ${input_consensus} \\
        --output-path ${output_consensus}
    """
}
