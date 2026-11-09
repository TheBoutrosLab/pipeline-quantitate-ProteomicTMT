// Module: Align FFId feature maps from the same fraction across plexes.
/**
 * Input: ordered run keys and featureXMLs. Output: one aligned featureXML per run; a
 * single run is copied.
 */
process align_MS1Features {
    container params.docker_image_openms
    input:
    tuple val(plexes), path(features)
    output:
    tuple val(plexes), path('*.aligned.featureXML')
    script:
    def inputs = features instanceof List ? features : [features]
    def aligned = plexes.collect { "${it}.aligned.featureXML" }.join(' ')
    if (inputs.size() == 1) {
        return "cp ${inputs[0]} ${plexes[0]}.aligned.featureXML"
    }
    """
    MapAlignerIdentification -in ${inputs.join(' ')} -out ${aligned} -threads ${task.cpus}
    """
}
