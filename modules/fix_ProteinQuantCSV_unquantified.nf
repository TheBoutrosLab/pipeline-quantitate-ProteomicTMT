// Module: Clean missing peptide values after scan-based normalization.
include { getToolArgs } from './common'

/**
 * Input: the dataset peptide CSV and resolved consensusXML. Output: one CSV with all-
 * zero plexes and unquantified channels marked missing.
 */
process fix_ProteinQuantCSV_unquantified {
    container params.docker_image_msptools

    publishDir "${params.final_output_dir}",
        mode: 'copy',
        pattern: "*_fixZeroPlex.csv",
        enabled: params.enable_tmt_normalization && (params.tmt_normalization_method == 'openms' || params.MADNormalizer.quasi_intensity)

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
    def program_options = params.fixZeroPlex ?: [:]
    def flag_options = ['greedy_group_resolution', 'nocheck_intensity'] as Set
    def extra_args = getToolArgs(program_options, flag_options, '--')
    // Charge-aggregated peptide rows use charge 0; the consensusXML lookup
    // expects the individual charge reported with -best_charge_and_fraction.
    consensus_arg = params.ProteinQuantifier.best_charge_and_fraction ? "--consensusXML ${consensusXML}" : ""
    """
    msptools ProteinQuantCSV fixZeroPlex \\
        --input-path ${input_csv} \\
        --output-path ${output_csv} \\
        ${consensus_arg} \\
        --type peptide \\
        ${extra_args}
    """
}
