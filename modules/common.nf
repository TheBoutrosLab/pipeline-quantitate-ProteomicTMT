/**
 * Common groovy functions
 */

/**
 * Get extra arguments from the params ConfigMap object to be parsed to processes using OpenMS
 * commands
 */
def getOpenMSArgs(ArrayList parameters, ArrayList flags, Map parameter_mapper, Map flag_mapper) {
    def getArgName = { it }
    return getArgsGeneral(parameters, flags, parameter_mapper, flag_mapper, getArgName)
}

def getPhilosopherArgs(ArrayList parameters, ArrayList flags, Map parameter_mapper, Map flag_mapper) {
    def getArgName = { it }
    return getArgsGeneral(parameters, flags, parameter_mapper, flag_mapper, getArgName)
}

def getArgsGeneral(ArrayList parameters, ArrayList flags, Map parameter_mapper, Map flag_mapper, Closure getArgName) {
    def args = ""
    parameters.each{ it ->
        if (params.containsKey(it) && params[it] != null) {
            args += " ${getArgName(it)} ${params[it]}"
        }
    }
    flags.each { it ->
        if (params.containsKey(it) && params[it] == true) {
            args += " ${getArgName(it)}"
        }
    }
    parameter_mapper.each { key, val ->
        if (params.containsKey(key) && params[key] != null) {
            args += " ${getArgName(val)} ${params[key]}"
        }
    }
    flag_mapper.each { key, val ->
        if (params.containsKey(key) && params[key] == true) {
            args += " ${getArgName(val)}"
        }
    }
    return args
}

def printPrelogue(){
    def options = [:]
    exclude_args = [
        'mzML_csv', 'consensusXML_csv', 'idXML_csv', 'channel_csv', 'decoy_database', 'output_dir', 'openms_version', 'docker_image_openms',
        'project_script_mount_options',
        'max_cpus', 'max_memory', 'philosopher_version', 'docker_image_philosopher',
        'intermediate_file_dir', 'process_log_dir', 'pipeline_log_dir', 'idXML', 'mzML', 'mz-ML',
        'id-XML'
    ]
    params.each { key, val ->
        if (!(key in exclude_args)) {
            val = val as String
            options[key] = val
        }
    }
    def options_str = ''
    def max_len = options.keySet().collect{it.size()}.max()
    options.each { key, val ->
        options_str += '\n' + ' ' * 12 + key.padRight(max_len + 1, ' ') + ": ${val}"
    }
    log.info """\
        =================================================================
        P I P E L I N E   Q U A N T I T A T E   P R O T E O M I C   T M T
        =================================================================
        Boutros Lab

        Current Configuration:
        - pipeline:
            name   : ${workflow.manifest.name}
            version: ${workflow.manifest.version}

        - input:
            mzML_csv       : ${params.containsKey('mzML_csv') ? params.mzML_csv : 'not set'}
            consensusXML_csv: ${params.containsKey('consensusXML_csv') ? params.consensusXML_csv : 'not set'}
            idXML_csv      : ${params.idXML_csv}
            channel_csv    : ${params.containsKey('channel_csv') ? params.channel_csv : 'not set'}

        - output:
            output_dir: ${params.output_dir}

        - options: ${options_str}

        Tools Used:
            OpenMS : ${params.docker_image_openms}

        ------------------------------------
        Starting workflow...
        ------------------------------------
    """
    .stripIndent()
}
