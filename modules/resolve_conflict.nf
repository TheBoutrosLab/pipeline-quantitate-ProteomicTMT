include { getOpenMSArgs } from "${moduleDir}/common"

PARAMETERS = []

FLAGS = []

PARAMETER_MAPPER = [
    'conflict_resolver_resolve_between_features': '-resolve_between_features'
]

FLAG_MAPPER = [:]

process resolve_conflict {
    container params.docker_image_openms

    publishDir "${params.final_output_dir}/${plex}",
        mode: 'copy',
        pattern: "*.consensusXML"

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        tuple val(plex), path(consensusXML)

    output:
        tuple val(plex), path(output_file)
        file ".command.*"

    script:
    output_file = "${plex}_IDConflictResolver.consensusXML"
    extra_args = getOpenMSArgs(PARAMETERS, FLAGS, PARAMETER_MAPPER, FLAG_MAPPER)
    """
    IDConflictResolver \\
        -in ${consensusXML} \\
        -out ${output_file} \\
        -threads ${task.cpus} \\
        ${extra_args}
    """
}
