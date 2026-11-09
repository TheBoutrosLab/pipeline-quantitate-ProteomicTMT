include { getToolArgs } from './common'

process sort_spectra {
    container params.docker_image_openms

    publishDir "${params.intermediate_file_dir}/${plex}/${task.process.replace(':', '/')}/",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: "*_sorted.mzML"

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        tuple val(plex), val(order), path(mzML), val(channels), val(plex_type), val(reference), val(correction)

    output:
        tuple val(plex), val(order), path(sorted_mzML), val(channels), val(plex_type), val(reference), val(correction)
        file ".command.*"

    script:
    sorted_mzML = "${plex}_${mzML.baseName}_sorted.mzML"
    if (params.FileFilter?.containsKey('sort')) {
        throw new IllegalArgumentException('FileFilter.sort is always enabled.')
    }
    def program_options = params.FileFilter ?: [:]
    def flag_options = [
        'sort', 'peak_options:sort_peaks', 'peak_options:no_chromatograms',
        'peak_options:remove_chromatograms', 'peak_options:remove_empty',
        'peak_options:remove_metadataarrays', 'spectra:remove_zoom',
        'spectra:select_zoom', 'consensus:map_and', 'f_and_c:remove_hull',
        'id:remove_clashes', 'id:keep_best_score_id',
        'id:remove_annotated_features', 'id:remove_unannotated_features',
        'id:remove_unassigned_ids', 'id:blacklist_imperfect'
    ] as Set
    def extra_args = getToolArgs(program_options, flag_options)
    """
    FileFilter \\
        -in ${mzML} \\
        -out ${sorted_mzML} \\
        -threads ${task.cpus} \\
        -sort ${extra_args}
    """
}
