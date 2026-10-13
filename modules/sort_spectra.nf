include { getOpenMSArgs } from "${moduleDir}/common"

PARAMETERS = []

FLAGS = []

PARAMETER_MAPPER = [:]

FLAG_MAPPER = [:]

process sort_spectra {
    container params.docker_image_openms

    publishDir "${params.intermediate_file_dir}/${task.process.replace(':', '/')}/",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: "*_sorted.mzML"

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        file(mzML)

    output:
        file(sorted_mzML)
        file ".command.*"

    script:
    sorted_mzML = "${mzML.baseName}_sorted.mzML"
    // extra_args = getOpenMSArgs(PARAMETERS, FLAGS, PARAMETER_MAPPER, FLAG_MAPPER)
    """
    FileFilter \\
        -in ${mzML} \\
        -out ${sorted_mzML} \\
        -threads ${task.cpus} \\
        -sort
    """
}
