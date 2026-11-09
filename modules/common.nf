/**
 * Common groovy functions
 */

/** Render nested tool options, preserving zero and false values. */
def getToolArgs(Map options, Set flags = [] as Set, String prefix = '-') {
    def args = []
    appendToolArgs(options ?: [:], [], flags, prefix, args)
    return args.join(' ')
}

def appendToolArgs(Map values, List path, Set flags, String prefix, List args) {
    values.each { key, value ->
        def parts = path + [key.toString()]
        if (value instanceof Map) {
            appendToolArgs(value, parts, flags, prefix, args)
        } else if (value != null) {
            if (parts.size() == 1 && parts[0] in ['in', 'out', 'id', 'threads', 'type',
                    'peptide_out', 'input_path', 'output_path', 'layout', 'scaling_report_path']) {
                throw new IllegalArgumentException("${parts[0]} is managed by the pipeline")
            }
            def name = parts.join(':')
            def option = "${prefix}${prefix == '--' ? name.replace('_', '-') : name}"
            if (name in flags) {
                if (!(value instanceof Boolean)) {
                    throw new IllegalArgumentException("${name} must be a boolean flag")
                }
                if (value) args << option
            } else {
                def items = value instanceof Collection ? value : [value]
                if (items.isEmpty()) {
                    throw new IllegalArgumentException("${name} cannot have an empty value list")
                }
                args << option
                items.each { item ->
                    def quoted = item.toString().replace("'", "'\"'\"'")
                    args << "'${quoted}'"
                }
            }
        }
    }
}

def printPrelogue(){
    def options = [:]
    def exclude_args = [
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
