include { getToolArgs } from './common'

process extract_isobaric {
    container params.docker_image_openms

    publishDir "${params.intermediate_file_dir}/${plex}/${task.process.replace(':', '/')}/",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: "*.consensusXML"

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        tuple val(plex), val(order), path(mzML), val(channels), val(plex_type), val(reference), val(correction)

    output:
        tuple val(plex), val(order), path(consensusXML)
        file ".command.*"

    script:
    consensusXML = "${mzML.baseName}.consensusXML"
    if (params.IsobaricAnalyzer?.quantification?.containsKey('normalization')) {
        throw new IllegalArgumentException('IsobaricAnalyzer.quantification.normalization is selected by tmt_normalization_method.')
    }
    def program_options = params.IsobaricAnalyzer ?: [:]
    // OpenMS treats only false-by-default boolean subsections as CLI flags.
    // purity_interpolation defaults to true and requires an explicit value.
    def flag_options = ['extraction:discard_low_intensity_quantifications'] as Set
    def extra_args = getToolArgs(program_options, flag_options)
    extra_args += " -type ${plex_type}"
    channels.each { chn ->
        extra_args += " -${plex_type}:channel_${chn[0]}_description ${chn[1]}"
    }
    if (correction) {
        extra_args += " -${plex_type}:correction_matrix ${correction}"
    }
    if (reference) {
        extra_args += " -${plex_type}:reference_channel ${reference}"
    }
    if (params.tmt_workflow != 'feature_based' && params.enable_tmt_normalization && params.tmt_normalization_method == 'openms') {
        extra_args += " -quantification:normalization"
    }
    """
    IsobaricAnalyzer \\
        -in ${mzML} \\
        -out ${consensusXML} \\
        -threads ${task.cpus} \\
        ${extra_args}
    """
}
