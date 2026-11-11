// Module: Optional MS1 feature-based TMT workflow from mzML and idXML inputs.
nextflow.enable.dsl = 2
include { sort_spectra } from './sort_spectra'
include { extract_isobaric } from './extract_isobaric'
include { set_ConsensusXMLFilename } from './set_ConsensusXMLFilename'
include { align_idXMLRunName } from './align_idXMLRunName'
include { map_idXML2consensusXML } from './map_idXML2consensusXML'
include { split_idXMLByMzML } from './split_idXMLByMzML'
include { find_MS1Features } from './find_MS1Features'
include { align_MS1Features } from './align_MS1Features'
include { allocate_TMTChannelAreas } from './allocate_TMTChannelAreas'
include { link_TMTFeatures } from './link_TMTFeatures'
include { annotate_LinkedTMTMeasurements } from './annotate_LinkedTMTMeasurements'
include { merge_ConsensusXML_TMTFractions } from './merge_ConsensusXML_TMTFractions'
include { merge_TMTFeatureTables } from './merge_TMTFeatureTables'
include { resolve_conflict } from './resolve_conflict'
include { quantify_peptides } from './quantify_peptides'
include { normalize_consensusXML_MAD } from './normalize_consensusXML_MAD'
include { fix_ProteinQuantCSV_unquantified } from './fix_ProteinQuantCSV_unquantified'

/**
 * Input: validated plex tuples with fraction IDs. Output: one dataset consensusXML,
 * peptide CSV, and linked-feature TSV, plus fraction-level intermediate files.
 */
workflow quantify_TMT_FeatureBased {
    take:
        plexes_ch

    main:
        // Each run is one plex/fraction pair. The manifest's fraction_id pairs
        // corresponding fractions across plexes without relying on CSV row order.
        runs = plexes_ch.flatMap { plex, sources, idxml, channels, plex_type, reference, correction, fractions ->
            sources.withIndex().collect { source, i ->
                def run_key = "${plex.length()}_${plex}_${fractions[i]}"
                tuple(run_key, plex, fractions[i], source, idxml, channels, plex_type, reference, correction)
            }
        }
        fractions_by_run = runs.map { key, plex, fraction, mzml, idxml, channels, type, reference, correction -> tuple(key, fraction) }
        split_idXMLByMzML(runs.map { key, plex, fraction, mzml, idxml, channels, type, reference, correction ->
            tuple(key, mzml, idxml)
        })
        find_MS1Features(split_idXMLByMzML.out[0])

        // FFId outputs are aligned only against the same fraction of other plexes.
        alignment_input = find_MS1Features.out[0].join(fractions_by_run)
            .map { key, feature, fraction -> tuple(fraction, key, feature) }
            .groupTuple(by: 0)
            .map { fraction, keys, features ->
                def order = new ArrayList(0..<keys.size()).sort { a, b -> keys[a] <=> keys[b] }
                tuple(fraction, order.collect { keys[it] }, order.collect { features[it] })
            }
        align_MS1Features(alignment_input.map { fraction, keys, features -> tuple(keys, features) })
        aligned = align_MS1Features.out[0].flatMap { keys, files ->
            def outputs = files instanceof List ? files : [files]
            outputs.collect { f -> tuple(f.name.replace('.aligned.featureXML', ''), f) }
        }

        spectra = runs.map { key, plex, fraction, mzml, idxml, channels, type, reference, correction ->
            tuple(key, 0, mzml, channels, type, reference, correction)
        }
        sort_spectra(spectra)
        extract_isobaric(sort_spectra.out[0])
        set_ConsensusXMLFilename(extract_isobaric.out[0].map { key, order, file -> tuple(key, file) })
        ids = split_idXMLByMzML.out[0].map { key, mzml, idxml -> tuple(key, idxml) }
        align_idXMLRunName(set_ConsensusXMLFilename.out[0].join(ids))
        map_idXML2consensusXML(set_ConsensusXMLFilename.out[0].join(align_idXMLRunName.out[0]))
        run_plex_ids = runs.map { key, plex, fraction, mzml, idxml, channels, type, reference, correction ->
            tuple(key, plex)
        }
        allocate_TMTChannelAreas(aligned.join(map_idXML2consensusXML.out[0]).join(run_plex_ids))

        // The linked feature result remains an independent cross-plex output.
        linked_input = allocate_TMTChannelAreas.out[0].join(fractions_by_run).join(run_plex_ids)
            .map { key, map, fraction, plex -> tuple(fraction, plex, map) }
            .groupTuple(by: 0)
            .map { fraction, plexes, maps ->
                def order = new ArrayList(0..<plexes.size()).sort { a, b -> plexes[a] <=> plexes[b] }
                tuple(fraction, order.collect { maps[it] })
            }
        link_TMTFeatures(linked_input)
        // FeatureLinker keeps channel handles but not the input element's metadata.
        // Join their stable handle IDs back to the per-run area and reporter values.
        values_by_fraction = allocate_TMTChannelAreas.out[1].join(fractions_by_run)
            .map { key, values, fraction -> tuple(fraction, values) }
            .groupTuple(by: 0)
        annotate_LinkedTMTMeasurements(link_TMTFeatures.out[0].join(values_by_fraction))

        // Every fraction now has the same plex/channel header order. Append their
        // linked maps into one experiment-wide consensusXML before peptide rollup.
        all_fraction_maps = annotate_LinkedTMTMeasurements.out[0]
            .toList()
            .map { rows -> rows.sort { a, b -> a[0] <=> b[0] }.collect { it[1] } }
        merge_ConsensusXML_TMTFractions(all_fraction_maps)
        all_fraction_tables = annotate_LinkedTMTMeasurements.out[1]
            .toList()
            .map { rows -> rows.sort { a, b -> a[0] <=> b[0] }.collect { it[1] } }
        if (params.enable_tmt_normalization) {
            normalize_consensusXML_MAD(merge_ConsensusXML_TMTFractions.out[0])
            consensus_for_quantification = normalize_consensusXML_MAD.out[0]
        } else {
            consensus_for_quantification = merge_ConsensusXML_TMTFractions.out[0]
        }
        resolve_conflict(consensus_for_quantification)
        merge_TMTFeatureTables(resolve_conflict.out[0], all_fraction_tables)
        quantify_peptides(resolve_conflict.out[0])
        peptide_for_cleanup = quantify_peptides.out[0]
        // MAD log2 ratios use zero for equality to the reference, so zero-plex
        // cleanup applies only to intensity-scale outputs.
        if (params.enable_tmt_normalization && (params.tmt_normalization_method == 'openms' || params.MADNormalizer.quasi_intensity)) {
            fix_ProteinQuantCSV_unquantified(peptide_for_cleanup, resolve_conflict.out[0])
            final_peptide_tables = fix_ProteinQuantCSV_unquantified.out[0]
        } else {
            final_peptide_tables = peptide_for_cleanup
        }

    emit:
        peptide_tables = final_peptide_tables
        consensusXML = resolve_conflict.out[0]
        linked_feature_tables = merge_TMTFeatureTables.out[0]
}
