
process remove_ConsensusMappedFeatures {
    container params.docker_image_pyopenms

    publishDir params.final_output_dir,
        mode: 'copy',
        pattern: "*.consensusXML"

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        file input_consensus
        path script_file

    output:
        file output_consensus
        file ".command.*"

    script:
    output_consensus = "${params.plex_name}_unmapped.consensusXML"
    """
    python ${script_file} \\
        --input-path ${input_consensus} \\
        --output-path ${output_consensus}
    """
}
