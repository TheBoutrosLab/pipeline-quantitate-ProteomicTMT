// Module: Resolve peptide-identification conflicts in the final dataset consensusXML.
include { getToolArgs } from './common'

/**
 * Input: one merged consensusXML. Output: one conflict-resolved consensusXML for
 * peptide quantification.
 */
process resolve_conflict {
    container params.docker_image_openms

    publishDir "${params.final_output_dir}",
        mode: 'copy',
        pattern: "*.consensusXML"

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        path(consensusXML)

    output:
        path(output_file)
        file ".command.*"

    script:
    output_file = "${params.dataset_id}_IDConflictResolver.consensusXML"
    def program_options = params.IDConflictResolver ?: [:]
    def flag_options = [] as Set
    def extra_args = getToolArgs(program_options, flag_options)
    """
    IDConflictResolver \\
        -in ${consensusXML} \\
        -out ${output_file} \\
        -threads ${task.cpus} \\
        ${extra_args}
    """
}
