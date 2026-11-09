"""Attach per-plex feature measurements to linked TMT channel handles."""
import argparse
import csv
import math

from pyopenms import ConsensusMap, ConsensusXMLFile


def text(value):
    """Normalize OpenMS string values."""
    return value.decode() if isinstance(value, bytes) else str(value)


def main():
    """Export linked feature/channel rows using stable channel-handle IDs."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--linked-consensus-xml', required=True)
    parser.add_argument('--values', required=True, nargs='+')
    parser.add_argument('--fraction-id', required=True)
    parser.add_argument('--output-tsv', required=True)
    parser.add_argument('--output-consensus-xml', required=True)
    args = parser.parse_args()

    source = {}
    for path in args.values:
        with open(path, newline='', encoding='utf-8') as handle:
            for row in csv.DictReader(handle, delimiter='\t'):
                key = int(row['channel_handle_id'])
                if key in source:
                    raise ValueError(f'Duplicate source channel handle ID: {key}')
                source[key] = row

    linked = ConsensusMap()
    ConsensusXMLFile().load(args.linked_consensus_xml, linked)
    headers = linked.getColumnHeaders()
    if not headers or any(not h.metaValueExists('channel_id') for h in headers.values()):
        raise ValueError('Linked TMT map lacks channel_id headers')
    linked.setExperimentType('labeled_MS2')
    seen = set()
    output = []
    for feature_index, feature in enumerate(linked):
        feature.setMetaValue('tmt_fraction_id', args.fraction_id)
        plex_values = {}
        for channel in feature.getFeatureList():
            key = channel.getUniqueId()
            if key not in source:
                raise ValueError(f'Linked channel handle {key} has no source record')
            if key in seen:
                raise ValueError(f'Linked channel handle {key} occurs twice')
            seen.add(key)
            row = source[key]
            header = headers[channel.getMapIndex()]
            if (text(header.filename) != row['plex_id'] or
                    text(header.label) != row['channel_label']):
                raise ValueError(f'Plex/channel header mismatch for handle {key}')
            if not math.isclose(channel.getIntensity(), float(row['estimated_channel_area']),
                                rel_tol=1e-6, abs_tol=1e-6):
                raise ValueError(f'Estimated area changed for handle {key}')
            plex_id = row['plex_id']
            feature.setMetaValue(f'tmt_reporter_sum::{plex_id}::{row["channel_label"]}',
                                 float(row['reporter_sum_channel']))
            identity = (row['source_feature_id'], row['ms1_area'],
                        row['reporter_sum_total'], row['scan_count'])
            if plex_id in plex_values and plex_values[plex_id] != identity:
                raise ValueError(f'Linked feature contains inconsistent values for plex {plex_id}')
            plex_values[plex_id] = identity
            sample_name = (text(header.getMetaValue('channel_description'))
                           if header.metaValueExists('channel_description') else '')
            output.append((feature.getUniqueId(), args.fraction_id,
                           row['plex_id'], row['channel_label'], sample_name,
                           channel.getMapIndex(), row['source_feature_id'],
                           row['ms1_area'],
                           row['reporter_sum_channel'], row['reporter_sum_total'],
                           row['estimated_channel_area'], row['scan_count'], key))
        for plex_id, (source_id, area, reporter_sum, scan_count) in plex_values.items():
            feature.setMetaValue(f'tmt_source_feature_id::{plex_id}', source_id)
            feature.setMetaValue(f'tmt_ms1_area::{plex_id}', float(area))
            feature.setMetaValue(f'tmt_reporter_sum::{plex_id}', float(reporter_sum))
            feature.setMetaValue(f'tmt_scan_count::{plex_id}', int(scan_count))
        # pyOpenMS iteration returns a copy, so write the annotated element back.
        linked[feature_index] = feature
    if seen != source.keys():
        raise ValueError(f'{len(source.keys() - seen)} source channel handles were lost '
                         'during linking')
    ConsensusXMLFile().store(args.output_consensus_xml, linked)
    with open(args.output_tsv, 'w', newline='', encoding='utf-8') as handle:
        writer = csv.writer(handle, delimiter='\t')
        writer.writerow(('linked_feature_id', 'fraction_id', 'plex_id', 'channel_label',
                         'sample_name', 'linked_map_index',
                         'source_feature_id', 'ms1_area', 'reporter_sum_channel',
                         'reporter_sum_total', 'estimated_channel_area', 'scan_count',
                         'channel_handle_id'))
        writer.writerows(output)
    print(f'Exported {len(output)} linked feature/channel rows')


if __name__ == '__main__':
    main()
