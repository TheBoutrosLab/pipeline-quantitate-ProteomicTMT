
process set_ConsensusXMLFilename {
    container params.docker_image_pyopenms

    publishDir "${params.intermediate_file_dir}/${task.process.replace(':', '/')}/",
        mode: 'copy',
        enabled: params.save_intermediate_files,
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
    output_consensus = "${input_consensus.baseName}_renamed.consensusXML"
    """
    python ${script_file} \\
        --input-path ${input_consensus} \\
        --output-path ${output_consensus} \\
        --filename ${params.plex_name}
    """
}
