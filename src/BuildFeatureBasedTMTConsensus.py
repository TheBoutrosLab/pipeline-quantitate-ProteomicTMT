"""Allocate integrated MS1 feature area across TMT channels using matched PSMs."""
import argparse
import csv
from collections import defaultdict

from pyopenms import BaseFeature, ColumnHeader, ConsensusFeature, ConsensusMap
from pyopenms import ConsensusXMLFile, FeatureMap, FeatureXMLFile, UniqueIdGenerator

def text(value):
    """Normalize OpenMS string values."""
    return value.decode() if isinstance(value, bytes) else str(value)


def reference(pid):
    """Return the native scan identifier carried by a peptide identification."""
    if pid.metaValueExists('spectrum_reference'):
        return text(pid.getMetaValue('spectrum_reference'))
    return ''


def best_sequence(pid):
    """Read the leading peptide assignment, if present."""
    hits = pid.getHits()
    return text(hits[0].getSequence().toString()) if hits else ''


def main():
    """Build one consensus element per FFId feature and report unmatched scans."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--feature-xml', required=True)
    parser.add_argument('--reporter-consensus-xml', required=True)
    parser.add_argument('--output-consensus-xml', required=True)
    parser.add_argument('--qc-tsv', required=True)
    parser.add_argument('--assignment-tsv', required=True)
    parser.add_argument('--values-tsv', required=True)
    parser.add_argument('--plex-id', required=True)
    args = parser.parse_args()

    fmap, reporters = FeatureMap(), ConsensusMap()
    FeatureXMLFile().load(args.feature_xml, fmap)
    ConsensusXMLFile().load(args.reporter_consensus_xml, reporters)
    headers = reporters.getColumnHeaders()
    if not headers:
        raise ValueError('Reporter map has no channel headers')
    if reporters.getExperimentType() != 'labeled_MS2':
        raise ValueError('Reporter map must be a labeled_MS2 TMT consensusXML')
    if any(not header.metaValueExists('channel_id') for header in headers.values()):
        raise ValueError('Reporter channel headers must contain channel_id metadata')
    by_scan = {}
    sequences_by_scan = {}
    for scan in reporters:
        ids = scan.getPeptideIdentifications()
        for pid in ids:
            key = reference(pid)
            if not key:
                continue
            if key in by_scan and by_scan[key].getUniqueId() != scan.getUniqueId():
                raise ValueError(f'Duplicate reporter scan reference: {key}')
            sequence = best_sequence(pid)
            if key in sequences_by_scan and sequences_by_scan[key] != sequence:
                raise ValueError(f'Conflicting peptide assignments for reporter scan {key}')
            by_scan[key] = scan
            sequences_by_scan[key] = sequence

    output = ConsensusMap()
    # ProteinQuantifier uses the labeled_MS2 type and channel_id headers to
    # interpret TMT handles as separate reporter assays.
    output.setExperimentType(reporters.getExperimentType())
    output.setProteinIdentifications(fmap.getProteinIdentifications())
    new_headers = {}
    for index, header in headers.items():
        new_header = ColumnHeader(header)
        new_header.filename = args.plex_id
        new_headers[index] = new_header
    output.setColumnHeaders(new_headers)
    qc_rows = []
    value_rows = []
    matched_features = 0
    assigned_scans = {}
    for feature in fmap:
        refs = {reference(pid) for pid in feature.getPeptideIdentifications() if reference(pid)}
        scan_refs = []
        for pid in feature.getPeptideIdentifications():
            key = reference(pid)
            if key and key in by_scan:
                if best_sequence(pid) != sequences_by_scan[key]:
                    raise ValueError(f'Peptide mismatch for reporter scan {key}')
                scan_refs.append(key)
        scan_refs = list(dict.fromkeys(scan_refs))
        scans = [by_scan[key] for key in scan_refs]
        if scans:
            matched_features += 1
        for scan_ref in scan_refs:
            if scan_ref in assigned_scans:
                raise ValueError(f'Reporter scan {scan_ref} maps to multiple MS1 features')
            assigned_scans[scan_ref] = feature.getUniqueId()
        totals = defaultdict(float)
        observed = set()
        for scan in scans:
            for handle in scan.getFeatureList():
                index = handle.getMapIndex()
                if index not in headers:
                    raise ValueError(f'Reporter handle references unknown channel {index}')
                totals[index] += handle.getIntensity()
                observed.add(index)
        if any(totals[index] < 0 for index in observed):
            raise ValueError('Feature-based reporter allocation requires nonnegative intensities')
        total = sum(totals[index] for index in observed)
        cf = ConsensusFeature()
        cf.setRT(feature.getRT())
        cf.setMZ(feature.getMZ())
        cf.setCharge(feature.getCharge())
        cf.setIntensity(feature.getIntensity())
        cf.setUniqueId(feature.getUniqueId())
        cf.setPeptideIdentifications(feature.getPeptideIdentifications())
        cf.setMetaValue('tmt_plex_id', args.plex_id)
        cf.setMetaValue('tmt_ms1_area', feature.getIntensity())
        cf.setMetaValue('tmt_reporter_sum', total)
        cf.setMetaValue('tmt_scan_count', len(scans))
        for index in sorted(observed):
            if total <= 0:
                continue
            channel = BaseFeature()
            channel.setRT(feature.getRT())
            channel.setMZ(feature.getMZ())
            channel.setCharge(feature.getCharge())
            channel.setIntensity(feature.getIntensity() * totals[index] / total)
            channel.setUniqueId(UniqueIdGenerator().getUniqueId())
            cf.insert(index, channel)
            value_rows.append((channel.getUniqueId(), feature.getUniqueId(), args.plex_id,
                               index, text(headers[index].label), feature.getIntensity(),
                               totals[index], total, channel.getIntensity(), len(scans)))
        output.push_back(cf)
        qc_rows.append((feature.getUniqueId(), len(refs), len(scans), len(observed), total))
    if not matched_features:
        raise ValueError('No FFId feature PSM matched an identified reporter scan')
    output.ensureUniqueId()
    ConsensusXMLFile().store(args.output_consensus_xml, output)
    with open(args.qc_tsv, 'w', newline='', encoding='utf-8') as handle:
        writer = csv.writer(handle, delimiter='\t')
        writer.writerow(('feature_id', 'psm_count', 'matched_scan_count',
                         'observed_channels', 'reporter_sum'))
        writer.writerows(qc_rows)
    with open(args.values_tsv, 'w', newline='', encoding='utf-8') as handle:
        writer = csv.writer(handle, delimiter='\t')
        writer.writerow(('channel_handle_id', 'source_feature_id', 'plex_id', 'channel_index',
                         'channel_label', 'ms1_area', 'reporter_sum_channel',
                         'reporter_sum_total', 'estimated_channel_area', 'scan_count'))
        writer.writerows(value_rows)
    with open(args.assignment_tsv, 'w', newline='', encoding='utf-8') as handle:
        writer = csv.writer(handle, delimiter='\t')
        writer.writerow(('spectrum_reference', 'peptide', 'feature_id'))
        for scan_ref in sorted(by_scan):
            writer.writerow((scan_ref, sequences_by_scan[scan_ref],
                             assigned_scans.get(scan_ref, '')))
    print(f'Wrote {len(qc_rows)} features; matched {len(assigned_scans)} of '
          f'{len(by_scan)} identified reporter scans')


if __name__ == '__main__':
    main()
