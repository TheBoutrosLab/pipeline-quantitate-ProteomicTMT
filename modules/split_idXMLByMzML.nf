// Module: Select identifications for one mzML run from a plex-level idXML.
/**
 * Input: run key, mzML, and plex idXML. Output: a run-specific idXML paired with that
 * mzML for FFId and reporter mapping.
 */
process split_idXMLByMzML {
    container params.docker_image_pyopenms
    containerOptions params.project_script_mount_options

    input:
        tuple val(run_key), path(mzml), path(idxml)

    output:
        tuple val(run_key), path(mzml), path("${run_key}.idXML")

    script:
    """
    python ${projectDir}/src/SplitTMTIdXMLByRun.py \\
        --input-idxml ${idxml} \\
        --mzml ${mzml} \\
        --output-idxml ${run_key}.idXML
    """
}
