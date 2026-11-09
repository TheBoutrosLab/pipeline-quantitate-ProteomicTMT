// Module: Find integrated MS1 features for one plex/fraction run.
/**
 * Input: mzML and its run-specific idXML. Output: FFId featureXML with peptide
 * identifications.
 */
process find_MS1Features {
    container params.docker_image_openms
    publishDir "${params.intermediate_file_dir}/${plex}/FFId", mode: 'copy', enabled: params.save_intermediate_files, pattern: '*.featureXML'

    input:
    tuple val(plex), path(mzml), path(idxml)

    output:
    tuple val(plex), path("${plex}.featureXML")

    script:
    """
    FeatureFinderIdentification -in ${mzml} -id ${idxml} -out ${plex}.featureXML -threads ${task.cpus}
    """
}
