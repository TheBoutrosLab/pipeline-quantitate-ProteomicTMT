include { getOpenMSArgs } from "${moduleDir}/common"

PARAMETERS = [

]

FLAGS = [

]

PARAMETER_MAPPER = [
    'protein_quantifier_format_separator': '--separator',
    'protein_quantifier_format_quoting': '--quoting'
]

FLAG_MAPPER = [:]

process fix_ProteinQuantCSV_unquantified {
    container params.docker_image_msptools

    publishDir "${params.final_output_dir}/${plex}",
        mode: 'copy',
        pattern: "*_fixZeroPlex.csv",
        enabled: params.enable_tmt_normalization == true

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        tuple val(plex), path(input_csv), path(consensusXML)

    output:
        tuple val(plex), path(output_csv)
        file ".command.*"

    script:
    output_csv = "${plex}_ProteinQuantifier_peptide_fixZeroPlex.csv"
    extra_args = getOpenMSArgs(PARAMETERS, FLAGS, PARAMETER_MAPPER, FLAG_MAPPER)
    // Charge-aggregated peptide rows use charge 0; the consensusXML lookup
    // expects the individual charge reported with -best_charge_and_fraction.
    consensus_arg = params.protein_quantifier_best_charge_and_fraction ? "--consensusXML ${consensusXML}" : ""
    """
    msptools ProteinQuantCSV fixZeroPlex \\
        --input-path ${input_csv} \\
        --output-path ${output_csv} \\
        ${consensus_arg} \\
        --type peptide \\
        ${extra_args}
    """
}
