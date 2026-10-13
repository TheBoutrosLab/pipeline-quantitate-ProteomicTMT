include { getOpenMSArgs } from "${moduleDir}/common"

PARAMETERS = [

]

FLAGS = [

]

PARAMETER_MAPPER = [
    'isobaric_analyzer_type': '-type',
    'isobaric_analyzer_extraction_select_activation': '-extraction:select_activation',
    'isobaric_analyzer_extraction_reporter_mass_shift': '-extraction:reporter_mass_shift',
    'isobaric_analyzer_extraction_min_precursor_intensity': '-extraction:min_precursor_intensity',
    'isobaric_analyzer_extraction_min_reporter_intensity': '-extraction:min_reporter_intensity',
    'isobaric_analyzer_extraction_min_precursor_purity': '-extraction:min_precursor_purity',
    'isobaric_analyzer_extraction_precursor_isotope_deviation': '-extraction:precursor_isotope_deviation',
    'isobaric_analyzer_extraction_keep_unannotated_precursor': '-extraction:keep_unannotated_precursor',
    'isobaric_analyzer_quantification_isotope_correction': '-quantification:isotope_correction'
]

FLAG_MAPPER = [
    'isobaric_analyzer_extraction_purity_interpolation': '-extraction:purity_interpolation',
    'isobaric_analyzer_extraction_discard_low_intensity_quantifications': '-extraction:discard_low_intensity_quantifications'
]

process extract_isobaric {
    container params.docker_image_openms

    publishDir "${params.intermediate_file_dir}/${task.process.replace(':', '/')}/",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: "*.consensusXML"

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        file mzML
        val channels

    output:
        file(consensusXML)
        file ".command.*"

    script:
    consensusXML = "${mzML.baseName}.consensusXML"
    extra_args = getOpenMSArgs(PARAMETERS, FLAGS, PARAMETER_MAPPER, FLAG_MAPPER)
    for (chn in channels) {
        extra_args += " -${params.isobaric_analyzer_type}:channel_${chn[0]}_description ${chn[1]}"
    }
    if (params.correction_matrix != null) {
        extra_args += " -${params.isobaric_analyzer_type}:correction_matrix ${params.correction_matrix}"
    }
    if (params.reference_channel != null) {
        extra_args += " -${params.isobaric_analyzer_type}:reference_channel ${params.reference_channel}"
    }
    if (params.enable_tmt_normalization && params.tmt_normalization_method == 'openms') {
        extra_args += " -quantification:normalization"
    }
    extra_args += ""
    """
    IsobaricAnalyzer \\
        -in ${mzML} \\
        -out ${consensusXML} \\
        -threads ${task.cpus} \\
        ${extra_args}
    """
}
