nextflow.enable.dsl = 2

include { printPrelogue } from "${projectDir}/modules/common"
include { sort_spectra } from "${projectDir}/modules/sort_spectra"
include { extract_isobaric } from "${projectDir}/modules/extract_isobaric"
include { merge_consensusXML } from "${projectDir}/modules/merge_consensusXML"
include { set_ConsensusXMLFilename } from "${projectDir}/modules/set_ConsensusXMLFilename"
include { align_idXMLRunName } from "${projectDir}/modules/align_idXMLRunName"
include { map_idXML2consensusXML } from "${projectDir}/modules/map_idXML2consensusXML"
include { remove_ConsensusMappedFeatures } from "${projectDir}/modules/remove_ConsensusMappedFeatures"
include { resolve_conflict } from "${projectDir}/modules/resolve_conflict"
include { quantify_peptides } from "${projectDir}/modules/quantify_peptides"
include { normalize_consensusXML_MAD } from "${projectDir}/modules/normalize_consensusXML_MAD"
include { filter_consensusXML_naFeatures } from "${projectDir}/modules/filter_consensusXML_naFeatures"
include { fix_ProteinQuantCSV_unquantified } from "${projectDir}/modules/fix_ProteinQuantCSV_unquantified"

def checked_plex_id(Object value) {
    def plex = value?.trim()
    if (!(plex ==~ /[A-Za-z0-9_.-]+/)) {
        error "Invalid plex_id ${plex.inspect()}; use letters, digits, dots, underscores, or hyphens."
    }
    plex
}

// Compare complete source and idXML manifests before creating any per-plex work.
// One idXML covers all mzML fractions belonging to the same plex.
def match_idxml_rows(List id_rows, Set source_names) {
    if (!id_rows) error 'The idXML CSV has no plex rows.'
    def ids = [:]
    id_rows.each { row ->
        if (!row.containsKey('plex_id') || !row.containsKey('idXML')) {
            error 'idXML CSV needs plex_id,idXML columns.'
        }
        def plex = checked_plex_id(row.plex_id)
        if (!row.idXML?.trim()) error "Plex ${plex}: idXML path is required."
        if (ids.containsKey(plex)) error "Plex ${plex}: idXML CSV must contain exactly one row."
        ids[plex] = row.idXML.trim()
    }
    def missing = source_names - ids.keySet()
    def extra = ids.keySet() - source_names
    if (missing || extra) {
        error "Source and idXML CSV plex names must match; missing idXML: ${missing}; extra idXML: ${extra}."
    }
    ids
}

// A premerged consensusXML is already one file per plex; no extraction or merge is needed.
def prepare_consensus_plexes(List consensus_rows, List id_rows) {
    if (!consensus_rows) error 'The consensusXML CSV has no plex rows.'
    consensus_rows.each { row ->
        if (!row.containsKey('plex_id') || !row.containsKey('consensusXML')) {
            error 'consensusXML CSV needs plex_id,consensusXML columns.'
        }
        checked_plex_id(row.plex_id)
        if (!row.consensusXML?.trim()) {
            error "Plex ${row.plex_id}: consensusXML path is required."
        }
    }
    def names = consensus_rows.collect { it.plex_id.trim() }
    if (names.toSet().size() != names.size()) {
        error 'consensusXML CSV must contain exactly one row per plex.'
    }
    def ids = match_idxml_rows(id_rows, names.toSet())
    consensus_rows.collect { row ->
        def plex = row.plex_id.trim()
        tuple(plex, file(row.consensusXML.trim(), checkIfExists: true),
              file(ids[plex], checkIfExists: true))
    }
}

// Build one tuple per plex from three independent manifests. Keep mzML paths in CSV
// order because FileMerger must receive that plex's fractions in a stable order.
def prepare_mzml_plexes(List mzml_rows, List id_rows, List channel_rows) {
    if (!mzml_rows) error 'The mzML CSV has no plex rows.'
    def required = ['plex_id', 'mzML']
    mzml_rows.each { row ->
        def missing = required.findAll { !row.containsKey(it) }
        if (missing) error "mzML CSV is missing columns: ${missing.join(', ')}"
        def plex = checked_plex_id(row.plex_id)
        if (!row.mzML?.trim()) error "Plex ${plex}: mzML path is required."
    }
    def rows_by_plex = mzml_rows.groupBy { it.plex_id.trim() }
    def ids = match_idxml_rows(id_rows, rows_by_plex.keySet())
    if (!channel_rows) error 'The channel CSV has no reporter channels.'
    channel_rows.each { row ->
        if (!['plex_id', 'channel', 'description'].every { row.containsKey(it) }) {
            error 'Channel CSV needs plex_id,channel,description columns.'
        }
        def plex = checked_plex_id(row.plex_id)
        if (!row.channel?.trim() || !row.description?.trim()) {
            error "Plex ${plex}: channel and description are required."
        }
    }
    // Split the shared channel manifest in memory so no plex receives another's labels.
    def channels_by_plex = channel_rows.groupBy { it.plex_id.trim() }
    def missing = rows_by_plex.keySet() - channels_by_plex.keySet()
    def extra = channels_by_plex.keySet() - rows_by_plex.keySet()
    if (missing || extra) {
        error "mzML and channel CSV plex IDs must match; missing channels: ${missing}; extra channels: ${extra}."
    }
    rows_by_plex.collect { plex, rows ->
        ['correction_matrix'].each { field ->
            if (rows.collect { (it[field] ?: '').trim() }.toSet().size() != 1) {
                error "Plex ${plex}: ${field} must be identical across its rows."
            }
        }
        def first = rows[0]
        def sources = rows.collect { file(it.mzML.trim(), checkIfExists: true) }
        if (sources.toSet().size() != sources.size() ||
            sources.collect { it.getFileName().toString() }.toSet().size() != sources.size()) {
            error "Plex ${plex}: mzML files must have unique paths and basenames."
        }
        def channels = channels_by_plex[plex].collect { [it.channel.trim(), it.description.trim()] }
        if (channels.collect { it[0] }.toSet().size() != channels.size()) {
            error "Plex ${plex}: channel CSV contains duplicate reporter channels."
        }
        // OpenMS needs the reporter label of the reference, not its sample description.
        def references = channels.findAll { it[1].equalsIgnoreCase('reference') }
        if (references.size() > 1) error "Plex ${plex}: channel CSV has multiple reference channels."
        def reference = references ? references[0][0] : ''
        // OpenMS always normalizes to a physical channel; MAD requires one
        // unless it computes a virtual reference.
        def needs_reference = params.enable_tmt_normalization &&
            (params.tmt_normalization_method == 'openms' || !params.virtual_reference)
        if (needs_reference && !reference) {
            error "Plex ${plex}: label one channel 'reference' for ${params.tmt_normalization_method} normalization."
        }
        tuple(plex, sources, file(ids[plex], checkIfExists: true), channels,
              params.plex_type, reference,
              first.correction_matrix?.trim() ?: '')
    }
}

printPrelogue()

workflow {
    id_rows_ch = Channel.fromPath(params.idXML_csv)
        .splitCsv(header: true)
        .toList()
        .map { rows -> tuple('all', rows) }

    if (params.consensusXML_entrypoint) {
        // This branch starts with one consensusXML per plex and skips mzML extraction.
        consensus_rows_ch = Channel.fromPath(params.consensusXML_csv)
            .splitCsv(header: true)
            .toList()
            .map { rows -> tuple('all', rows) }

        consensus_plexes = consensus_rows_ch.join(id_rows_ch)
            .flatMap { ignored_key, consensus_rows, id_rows ->
                try {
                    prepare_consensus_plexes(consensus_rows, id_rows)
                } catch (java.lang.reflect.InvocationTargetException exception) {
                    error exception.cause?.message ?: exception.message
                }
            }
        merged_consensusXML = consensus_plexes.map { plex, consensus, id_file ->
            tuple(plex, consensus)
        }
        plex_ids = consensus_plexes.map { plex, consensus, id_file ->
            tuple(plex, id_file)
        }
    } else {
        // Join complete manifests, then emit independent plex tuples for parallel work.
        mzml_rows_ch = Channel.fromPath(params.mzML_csv).splitCsv(header: true)
            .toList().map { rows -> tuple('all', rows) }
        channel_rows_ch = Channel.fromPath(params.channel_csv).splitCsv(header: true)
            .toList().map { rows -> tuple('all', rows) }
        mzml_plexes = mzml_rows_ch.join(id_rows_ch).join(channel_rows_ch)
            .flatMap { ignored_key, mzml_rows, id_rows, channel_rows ->
                try {
                    prepare_mzml_plexes(mzml_rows, id_rows, channel_rows)
                } catch (java.lang.reflect.InvocationTargetException exception) {
                    error exception.cause?.message ?: exception.message
                }
            }
        plex_ids = mzml_plexes.map { plex, sources, id_file, channels,
                                      plex_type, reference, correction -> tuple(plex, id_file) }
        mzml_inputs = mzml_plexes.flatMap { plex, sources, id_file, channels,
                                             plex_type, reference, correction ->
            // Extraction runs per mzML. Carry its manifest position through the
            // parallel tasks so their completion order cannot reorder fractions.
            sources.withIndex().collect { source, order ->
                tuple(plex, order, source, channels, plex_type, reference, correction)
            }
        }
        sort_spectra(mzml_inputs)
        extract_isobaric(sort_spectra.out[0])
        // groupTuple() gathers only files with the same plex key; restore CSV order.
        merge_consensusXML(extract_isobaric.out[0].groupTuple().map { plex, orders, files ->
            def sorted = new ArrayList(0..<orders.size()).sort { a, b -> orders[a] <=> orders[b] }
            tuple(plex, sorted.collect { files[it] })
        })
        set_ConsensusXMLFilename(merge_consensusXML.out[0])
        merged_consensusXML = set_ConsensusXMLFilename.out[0]
    }

    // Both entry points now provide (plex_id, consensusXML) tuples to the same
    // normalization, identification, and quantification path.
    if (params.enable_tmt_normalization && params.tmt_normalization_method == 'mad') {
        normalize_consensusXML_MAD(merged_consensusXML)
        // Removing NaN handles can shift ProteinQuantifier values under later CSV headers.
        if (params.filter_na_consensus_handles) {
            filter_consensusXML_naFeatures(normalize_consensusXML_MAD.out[0])
            consensus_for_mapping = filter_consensusXML_naFeatures.out[0]
        } else {
            consensus_for_mapping = normalize_consensusXML_MAD.out[0]
        }
    } else {
        consensus_for_mapping = merged_consensusXML
    }

    // Match by plex_id, then align the idXML run name with the consensus map so
    // IDMapper can associate spectrum references with quantified features.
    align_idXMLRunName(consensus_for_mapping.join(plex_ids))
    map_idXML2consensusXML(consensus_for_mapping.join(align_idXMLRunName.out[0]))

    if (params.remove_mapped_consensus) {
        remove_ConsensusMappedFeatures(map_idXML2consensusXML.out[0])
    }

    resolve_conflict(map_idXML2consensusXML.out[0])
    quantify_peptides(resolve_conflict.out[0])
    if (params.enable_tmt_normalization) {
        fix_ProteinQuantCSV_unquantified(quantify_peptides.out[0].join(resolve_conflict.out[0]))
    }
}
