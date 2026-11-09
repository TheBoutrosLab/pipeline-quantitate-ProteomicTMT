include { getOpenMSArgs } from "${moduleDir}/common"

PARAMETERS = [

]

FLAGS = [

]

PARAMETER_MAPPER = [
    'min_int': '--min-int',
    'virtual_reference_method': '--virtual-reference-method',
    'virtual_reference_min_channels': '--virtual-reference-min-channels'
]

FLAG_MAPPER = [
    'virtual_reference': '--virtual-reference',
    'mad_normalizer_quasi_intensity': '--quasi-intensity',
    'mad_normalizer_bridge_scale': '--bridge-scale',
    'mad_normalizer_allow_virtual_bridge': '--allow-virtual-bridge'
]

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
    extra_args = getOpenMSArgs(PARAMETERS, FLAGS, PARAMETER_MAPPER, FLAG_MAPPER)
    """
    msptools ConsensusXML MADNormalizer \\
        --input-path ${input_consensus} \\
        --output-path ${output_consensus} \\
        --layout ${layout} \\
        --scaling-report-path ${scaling_report} \\
        ${extra_args}
    """
}
