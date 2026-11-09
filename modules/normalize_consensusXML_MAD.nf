include { getToolArgs } from './common'

process normalize_consensusXML_MAD {
    container params.docker_image_msptools

    publishDir "${params.intermediate_file_dir}/${params.dataset_id}/${task.process.replace(':', '/')}/",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: "*.consensusXML"

    publishDir "${params.final_output_dir}", mode: 'copy', pattern: "*.consensusXML"
    publishDir "${params.final_output_dir}", mode: 'copy', pattern: "*_scaling.tsv"

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        path(input_consensus)

    output:
        path(output_consensus)
        path(scaling_report)
        file ".command.*"

    script:
    output_consensus = "${params.dataset_id}_MADNormalizer.consensusXML"
    scaling_report = "${params.dataset_id}_MADNormalizer_scaling.tsv"
    layout = params.tmt_workflow == 'feature_based' ? 'linked' : 'scan'
    def program_options = params.MADNormalizer ?: [:]
    def flag_options = ['virtual_reference', 'quasi_intensity', 'bridge_scale', 'allow_virtual_bridge'] as Set
    def extra_args = getToolArgs(program_options, flag_options, '--')
    """
    msptools ConsensusXML MADNormalizer \\
        --input-path ${input_consensus} \\
        --output-path ${output_consensus} \\
        --layout ${layout} \\
        --scaling-report-path ${scaling_report} \\
        ${extra_args}
    """
}
