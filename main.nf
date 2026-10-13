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

printPrelogue()

workflow {
    if (params.containsKey('input_csv')) {
        channel_description = Channel.fromPath(params.channel_description).splitCsv(header:true)
            .map{ [[it.channel, it.description]] }
            .collect()

        mzML = Channel.fromPath(params.input_csv).splitCsv(header:true).map{[file(it.path)]}
        sort_spectra(mzML)
        extract_isobaric(sort_spectra.out[0], channel_description)
        merge_consensusXML(extract_isobaric.out[0].collect())
        set_ConsensusXMLFilename(merge_consensusXML.out[0], file("${projectDir}/src/ConsensusXMLFileRenamer.py"))
        merged_consensusXML = set_ConsensusXMLFilename.out[0]
    } else {
        merged_consensusXML = file(params.merged_consensusXML)
    }

    if (params.enable_tmt_normalization && params.tmt_normalization_method == 'mad') {
        normalize_consensusXML_MAD(merged_consensusXML)
        // Keep NaN reporter handles by default: removing one makes ProteinQuantifier
        // omit that channel's CSV field and shift later values under the wrong headers.
        if (params.filter_na_consensus_handles) {
            filter_consensusXML_naFeatures(normalize_consensusXML_MAD.out[0])
            consensus_for_mapping = filter_consensusXML_naFeatures.out[0]
        } else {
            consensus_for_mapping = normalize_consensusXML_MAD.out[0]
        }
    } else {
        consensus_for_mapping = merged_consensusXML
    }

    align_idXMLRunName(consensus_for_mapping, params.idXML, file("${projectDir}/src/AlignIdXMLRunName.py"))
    map_idXML2consensusXML(consensus_for_mapping, align_idXMLRunName.out[0])

    if (params.remove_mapped_consensus) {
        remove_ConsensusMappedFeatures(map_idXML2consensusXML.out[0], file("${projectDir}/src/ConsensusIDRemover.py"))
    }

    resolve_conflict(map_idXML2consensusXML.out[0])
    quantify_peptides(resolve_conflict.out[0])
    if (params.enable_tmt_normalization) {
        fix_ProteinQuantCSV_unquantified(quantify_peptides.out[0], resolve_conflict.out[0])
    }
}
