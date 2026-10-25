include { getOpenMSArgs } from "${moduleDir}/common"

PARAMETERS = [

]

FLAGS = [

]

PARAMETER_MAPPER = [
    'id_mapper_rt_tolerance': '-rt_tolerance',
    'id_mapper_mz_tolerance': '-mz_tolerance',
    'id_mapper_mz_measure': '-mz_measure',
    'id_mapper_mz_reference': '-mz_reference',
    'id_mapper_feature_use_centroid_rt': '-feature:use_centroid_rt',
    'id_mapper_feature_use_centroid_mz': '-feature:use_centroid_mz'
]

FLAG_MAPPER = [
    'id_mapper_consensus_use_subelements': '-consensus:use_subelements',
    'id_mapper_consensus_annotate_ids_with_subelements': '-consensus:annotate_ids_with_subelements'
]

process map_idXML2consensusXML {
    container params.docker_image_openms

    publishDir "${params.final_output_dir}/${plex}",
        mode: 'copy',
        pattern: "*.consensusXML"

    publishDir "${params.intermediate_file_dir}/${plex}/${task.process.replace(':', '/')}/",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: "*.consensusXML"

    publishDir "${params.process_log_dir}/${task.process.replace(':', '/')}-${task.index}/",
        mode: 'copy',
        pattern: '.command.*',
        saveAs: { "log${file(it).name}" }

    input:
        tuple val(plex), path(consensusXML), path(idXML)

    output:
        tuple val(plex), path(output_file)
        file ".command.*"

    script:
    output_file = "${plex}_IDMapper.consensusXML"
    extra_args = getOpenMSArgs(PARAMETERS, FLAGS, PARAMETER_MAPPER, FLAG_MAPPER)
    """
    IDMapper \\
        -id ${idXML} \\
        -in ${consensusXML} \\
        -out ${output_file} \\
        -threads ${task.cpus} \\
        ${extra_args}
    """
}
