// Module: Quantify peptides from the final dataset consensusXML.
include { getOpenMSArgs } from "${moduleDir}/common"

PARAMETERS = []

FLAGS = []

PARAMETER_MAPPER = [
    'protein_quantifier_format_separator': '-format:separator',
    'protein_quantifier_format_quoting': '-format:quoting',
    'protein_quantifier_format_replacement': '-format:replacement'
]

FLAG_MAPPER = [
    'protein_quantifier_best_charge_and_fraction': '-best_charge_and_fraction'
]

/**
 * Input: one conflict-resolved consensusXML. Output: one OpenMS ProteinQuantifier
 * peptide CSV named with dataset_id.
 */
process quantify_peptides {
    container params.docker_image_openms

    publishDir "${params.final_output_dir}",
        mode: 'copy',
        pattern: "*.csv",
        enabled: (!params.enable_tmt_normalization || (params.tmt_normalization_method == 'mad' && !params.mad_normalizer_quasi_intensity)) && !params.protein_quantifier_best_charge_and_fraction

    publishDir "${params.intermediate_file_dir}/${params.dataset_id}/${task.process.replace(':','/')}",
        enabled: params.save_intermediate_files,
        mode: 'copy',
        pattern: "*.csv"

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        path(consensusXML)

    output:
        path(peptide_out)
        file ".command.*"

    script:
    peptide_out = "${params.dataset_id}_ProteinQuantifier_peptide.csv"
    extra_args = getOpenMSArgs(PARAMETERS, FLAGS, PARAMETER_MAPPER, FLAG_MAPPER)
    """
    ProteinQuantifier \\
        -in ${consensusXML} \\
        -peptide_out ${peptide_out} \\
        -threads ${task.cpus} \\
        ${extra_args}
    """
}
