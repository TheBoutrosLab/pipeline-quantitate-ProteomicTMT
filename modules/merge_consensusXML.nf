include { getToolArgs } from './common'

process merge_consensusXML {
    container params.docker_image_openms

    publishDir "${params.intermediate_file_dir}/${plex}/${task.process.replace(':', '/')}",
        mode: 'copy',
        enabled: params.save_intermediate_files,
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
    output_file = "${plex}_FileMerger.consensusXML"
    if (params.FileMerger?.containsKey('append_method')) {
        throw new IllegalArgumentException('FileMerger.append_method is fixed to append_rows.')
    }
    def program_options = params.FileMerger ?: [:]
    def flag_options = ['annotate_file_origin', 'raw:rt_auto', 'raw:rt_filename'] as Set
    def extra_args = getToolArgs(program_options, flag_options)
    """
    FileMerger \\
        -in ${consensusXML} \\
        -out ${output_file} \\
        -threads ${task.cpus} \\
        -append_method append_rows ${extra_args}
    """
}
