process filter_consensusXML_naFeatures {
    container params.docker_image_msptools

    publishDir "${params.intermediate_file_dir}/${plex}/${task.process.replace(':', '/')}/",
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
    output_consensus = "${plex}_removeNA.consensusXML"
    """
    msptools ConsensusXML removeNA \\
        --input-path ${input_consensus} \\
        --output-path ${output_consensus}
    """
}
