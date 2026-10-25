process align_idXMLRunName {
    container params.docker_image_pyopenms
    containerOptions params.project_script_mount_options

    publishDir "${params.intermediate_file_dir}/${plex}/${task.process.replace(':', '/')}/",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: '*.idXML'

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        tuple val(plex), path(consensusXML), path(idXML)

    output:
        tuple val(plex), path(output_idXML)
        path '.command.*'

    script:
    output_idXML = "${plex}_aligned.idXML"
    """
    python ${projectDir}/src/AlignIdXMLRunName.py \\
        --consensus-xml ${consensusXML} \\
        --input-idxml ${idXML} \\
        --output-idxml ${output_idXML}
    """
}
