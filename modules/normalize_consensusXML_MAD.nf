include { getOpenMSArgs } from "${moduleDir}/common"

PARAMETERS = [

]

FLAGS = [

]

PARAMETER_MAPPER = [
    'min_int': '--min-int',
    'virtual_reference_method': '--virtual-reference-method'
]

FLAG_MAPPER = [
    'virtual_reference': '--virtual-reference',
    'mad_normalizer_quasi_intensity': '--quasi-intensity'
]

process normalize_consensusXML_MAD {
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
    output_consensus = "${input_consensus.baseName}_MADNormalizer.consensusXML"
    extra_args = getOpenMSArgs(PARAMETERS, FLAGS, PARAMETER_MAPPER, FLAG_MAPPER)
    """
    msptools ConsensusXML MADNormalizer \\
        --input-path ${input_consensus} \\
        --output-path ${output_consensus} \\
        ${extra_args}
    """
}
