// Module: Restore abundance fields omitted by OpenMS 3.5 ProteinQuantifier.
/**
 * Input: a detailed peptide CSV and its resolved consensusXML. Output: a full-width
 * peptide CSV whose abundance values remain under their plex-specific headers.
 */
process repair_ProteinQuantCSV_columns {
    container params.docker_image_pyopenms
    containerOptions params.project_script_mount_options

    publishDir "${params.intermediate_file_dir}/${params.dataset_id}/${task.process.replace(':', '/')}",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: '*.csv'

    publishDir "${params.final_output_dir}",
        mode: 'copy',
        enabled: (!params.enable_tmt_normalization || (params.tmt_normalization_method == 'mad' && !params.mad_normalizer_quasi_intensity)),
        pattern: '*_repaired.csv',
        saveAs: { "${params.dataset_id}_ProteinQuantifier_peptide.csv" }

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        path(input_csv)
        path(consensusXML)

    output:
        path(output_csv)
        file '.command.*'

    script:
    output_csv = "${params.dataset_id}_ProteinQuantifier_peptide_repaired.csv"
    """
    python ${projectDir}/src/RepairProteinQuantCSVColumns.py \\
        --input-csv ${input_csv} \\
        --consensus-xml ${consensusXML} \\
        --output-csv ${output_csv}
    """
}
