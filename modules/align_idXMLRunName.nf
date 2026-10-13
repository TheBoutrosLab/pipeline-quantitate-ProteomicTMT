process align_idXMLRunName {
    container params.docker_image_pyopenms

    publishDir "${params.intermediate_file_dir}/${task.process.replace(':', '/')}/",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: '*.idXML'

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        path consensusXML
        path idXML
        path script_file

    output:
        path output_idXML
        path '.command.*'

    script:
    output_idXML = "${params.plex_name}_aligned.idXML"
    """
    python ${script_file} \\
        --consensus-xml ${consensusXML} \\
        --input-idxml ${idXML} \\
        --output-idxml ${output_idXML}
    """
}
