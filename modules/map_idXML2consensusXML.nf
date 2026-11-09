include { getToolArgs } from './common'

process map_idXML2consensusXML {
    container params.docker_image_openms

    publishDir "${params.intermediate_file_dir}/${plex}/${task.process.replace(':', '/')}/",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: "*.consensusXML"

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        tuple val(plex), path(consensusXML), path(idXML)

    output:
        tuple val(plex), path(output_file)
        file ".command.*"

    script:
    output_file = "${plex}_IDMapper.consensusXML"
    def program_options = params.IDMapper ?: [:]
    def flag_options = ['ignore_charge', 'consensus:use_subelements',
        'consensus:annotate_ids_with_subelements'] as Set
    def extra_args = getToolArgs(program_options, flag_options)
    """
    IDMapper \\
        -id ${idXML} \\
        -in ${consensusXML} \\
        -out ${output_file} \\
        -threads ${task.cpus} \\
        ${extra_args}
    """
}
