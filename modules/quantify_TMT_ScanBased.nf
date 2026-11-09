// Module: Reporter-scan-based TMT workflow for mzML or premerged consensusXML inputs.
nextflow.enable.dsl = 2

include { sort_spectra } from './sort_spectra'
include { extract_isobaric } from './extract_isobaric'
include { merge_consensusXML } from './merge_consensusXML'
include { merge_ConsensusXML_TMTPlexes } from './merge_ConsensusXML_TMTPlexes'
include { set_ConsensusXMLFilename } from './set_ConsensusXMLFilename'
include { align_idXMLRunName } from './align_idXMLRunName'
include { map_idXML2consensusXML } from './map_idXML2consensusXML'
include { remove_ConsensusMappedFeatures } from './remove_ConsensusMappedFeatures'
include { resolve_conflict } from './resolve_conflict'
include { quantify_peptides } from './quantify_peptides'
include { normalize_consensusXML_MAD } from './normalize_consensusXML_MAD'
include { filter_consensusXML_naFeatures } from './filter_consensusXML_naFeatures'
include { fix_ProteinQuantCSV_unquantified } from './fix_ProteinQuantCSV_unquantified'
include { repair_ProteinQuantCSV_columns } from './repair_ProteinQuantCSV_columns'

/**
 * Input: validated plex tuples. Output: one dataset consensusXML and peptide CSV after
 * per-plex extraction and ID mapping, followed by dataset-level normalization.
 */
workflow quantify_TMT_ScanBased {
    take:
        plexes_ch

    main:
        if (params.consensusXML_entrypoint) {
            // Premerged input already has one consensusXML and one idXML per plex.
            set_ConsensusXMLFilename(plexes_ch.map { plex, consensus, id_file -> tuple(plex, consensus) })
            merged_consensusXML = set_ConsensusXMLFilename.out[0]
            plex_ids = plexes_ch.map { plex, consensus, id_file -> tuple(plex, id_file) }
        } else {
            plex_ids = plexes_ch.map { plex, sources, id_file, channels,
                                    plex_type, reference, correction -> tuple(plex, id_file) }
            mzml_inputs = plexes_ch.flatMap { plex, sources, id_file, channels,
                                            plex_type, reference, correction ->
                // Carry CSV position through parallel tasks so FileMerger preserves source order.
                sources.withIndex().collect { source, order ->
                    tuple(plex, order, source, channels, plex_type, reference, correction)
                }
            }
            sort_spectra(mzml_inputs)
            extract_isobaric(sort_spectra.out[0])
            merge_consensusXML(extract_isobaric.out[0].groupTuple().map { plex, orders, files ->
                def sorted = new ArrayList(0..<orders.size()).sort { a, b -> orders[a] <=> orders[b] }
                tuple(plex, sorted.collect { files[it] })
            })
            set_ConsensusXMLFilename(merge_consensusXML.out[0])
            merged_consensusXML = set_ConsensusXMLFilename.out[0]
        }

        // Map identifications against the unnormalized per-plex maps. MAD runs
        // once all identified plexes have been appended to the dataset map.
        consensus_for_mapping = merged_consensusXML

        align_idXMLRunName(consensus_for_mapping.join(plex_ids))
        map_idXML2consensusXML(consensus_for_mapping.join(align_idXMLRunName.out[0]))
        if (params.remove_mapped_consensus) {
            remove_ConsensusMappedFeatures(map_idXML2consensusXML.out[0])
        }
        // Plexes are independent assays: append columns so their reporter
        // labels and channel handles remain distinct in the dataset map.
        all_plex_maps = map_idXML2consensusXML.out[0].toList().map { rows ->
            def ordered = rows.sort { a, b -> a[0] <=> b[0] }
            ordered.collect { it[1] }
        }
        merge_ConsensusXML_TMTPlexes(all_plex_maps)
        if (params.enable_tmt_normalization && params.tmt_normalization_method == 'mad') {
            normalize_consensusXML_MAD(merge_ConsensusXML_TMTPlexes.out[0])
            if (params.filter_na_consensus_handles) {
                filter_consensusXML_naFeatures(normalize_consensusXML_MAD.out[0])
                consensus_for_quantification = filter_consensusXML_naFeatures.out[0]
            } else {
                consensus_for_quantification = normalize_consensusXML_MAD.out[0]
            }
        } else {
            consensus_for_quantification = merge_ConsensusXML_TMTPlexes.out[0]
        }
        resolve_conflict(consensus_for_quantification)
        quantify_peptides(resolve_conflict.out[0])
        if (params.ProteinQuantifier.best_charge_and_fraction) {
            // OpenMS 3.5 can omit fields for plexes where a peptide is absent.
            repair_ProteinQuantCSV_columns(quantify_peptides.out[0], resolve_conflict.out[0])
            peptide_for_cleanup = repair_ProteinQuantCSV_columns.out[0]
        } else {
            peptide_for_cleanup = quantify_peptides.out[0]
        }
        // MAD log2 ratios use zero for equality to the reference, so zero-plex
        // cleanup applies only to intensity-scale outputs.
        if (params.enable_tmt_normalization && (params.tmt_normalization_method == 'openms' || params.MADNormalizer.quasi_intensity)) {
            fix_ProteinQuantCSV_unquantified(peptide_for_cleanup, resolve_conflict.out[0])
            final_peptide_tables = fix_ProteinQuantCSV_unquantified.out[0]
        } else {
            final_peptide_tables = peptide_for_cleanup
        }

    emit:
        consensusXML = resolve_conflict.out[0]
        peptide_tables = final_peptide_tables
}
