// Module: Clean missing peptide values after scan-based normalization.
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

/**
 * Input: the dataset peptide CSV and resolved consensusXML. Output: one CSV with all-
 * zero plexes and unquantified channels marked missing.
 */
process fix_ProteinQuantCSV_unquantified {
    container params.docker_image_msptools

    publishDir "${params.final_output_dir}",
        mode: 'copy',
        pattern: "*_fixZeroPlex.csv",
        enabled: params.enable_tmt_normalization && (params.tmt_normalization_method == 'openms' || params.mad_normalizer_quasi_intensity)

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        path(input_csv)
        path(consensusXML)

    output:
        path(output_csv)
        file ".command.*"

    script:
    output_csv = "${params.dataset_id}_ProteinQuantifier_peptide_fixZeroPlex.csv"
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
