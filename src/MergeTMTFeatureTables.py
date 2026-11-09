"""Concatenate linked TMT rows from every fraction without aggregating values.

Match each source linked-feature ID to the final consensusXML, because OpenMS may
replace duplicate IDs while appending fraction maps.
"""
import argparse
import csv

from pyopenms import ConsensusMap, ConsensusXMLFile


def text(value):
    """Normalize OpenMS string values."""
    return value.decode() if isinstance(value, bytes) else str(value)


REQUIRED = {'linked_feature_id', 'fraction_id', 'plex_id', 'channel_label',
            'estimated_channel_area'}


def main():
    """Preserve every source row while checking the shared table schema."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--consensus-xml', required=True)
    parser.add_argument('--inputs', nargs='+', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()

    consensus = ConsensusMap()
    ConsensusXMLFile().load(args.consensus_xml, consensus)
    final_ids = {}
    normalized_handles = {}
    scale_factors = {}
    headers = consensus.getColumnHeaders()
    normalized = any(feature.metaValueExists('plex_scale_factor::' + text(header.filename))
                     for feature in consensus for header in headers.values())
    for feature in consensus:
        if (not feature.metaValueExists('tmt_fraction_id') or
                not feature.metaValueExists('tmt_source_linked_feature_id')):
            raise ValueError('Cohort consensusXML lacks fraction/source feature IDs')
        fraction = text(feature.getMetaValue('tmt_fraction_id'))
        source_id = text(feature.getMetaValue('tmt_source_linked_feature_id'))
        key = (fraction, source_id)
        if key in final_ids:
            raise ValueError(f'Duplicate cohort feature key: {key}')
        final_id = str(feature.getUniqueId())
        final_ids[key] = final_id
        if normalized:
            for handle in feature.getFeatureList():
                index = handle.getMapIndex()
                plex = text(headers[index].filename)
                scale_key = f'plex_scale_factor::{plex}'
                if not feature.metaValueExists(scale_key):
                    raise ValueError(f'Normalized feature {final_id} lacks {scale_key}')
                normalized_handles[(final_id, index)] = (
                    handle.getUniqueId(), handle.getIntensity())
                scale_factors[(final_id, index)] = float(feature.getMetaValue(scale_key))

    fieldnames = None
    seen = set()
    rows = []
    fractions = set()
    for path in args.inputs:
        with open(path, newline='', encoding='utf-8') as handle:
            reader = csv.DictReader(handle, delimiter='\t')
            if not reader.fieldnames or not REQUIRED.issubset(reader.fieldnames):
                raise ValueError(f'{path}: missing linked TMT table columns')
            if fieldnames is None:
                fieldnames = list(reader.fieldnames)
                if normalized:
                    fieldnames += ['normalized_channel_area', 'plex_scale_factor']
            elif reader.fieldnames != fieldnames[:len(reader.fieldnames)]:
                raise ValueError(f'{path}: linked TMT columns differ from the first table')
            file_fractions = set()
            for row in reader:
                fraction = row['fraction_id']
                source_key = (fraction, row['linked_feature_id'])
                if source_key not in final_ids:
                    raise ValueError(f'{path}: linked feature absent from cohort map: {source_key}')
                row['linked_feature_id'] = final_ids[source_key]
                if normalized:
                    index = int(row['linked_map_index'])
                    handle_key = (row['linked_feature_id'], index)
                    if handle_key not in normalized_handles:
                        raise ValueError(f'{path}: normalized channel absent: {handle_key}')
                    handle_id, area = normalized_handles[handle_key]
                    if handle_id != int(row['channel_handle_id']):
                        raise ValueError(f'{path}: normalized channel handle changed: {handle_key}')
                    header = headers[index]
                    if (text(header.filename) != row['plex_id'] or
                            text(header.label) != row['channel_label']):
                        raise ValueError(
                            f'{path}: normalized channel header mismatch: {handle_key}')
                    row['normalized_channel_area'] = area
                    row['plex_scale_factor'] = scale_factors[handle_key]
                key = (fraction, row['linked_feature_id'], row['plex_id'], row['channel_label'])
                if not all(key) or key in seen:
                    raise ValueError(
                        f'{path}: empty or duplicate linked feature/channel key: {key}')
                seen.add(key)
                file_fractions.add(fraction)
                rows.append(row)
            if len(file_fractions) != 1:
                raise ValueError(f'{path}: expected exactly one fraction_id')
            if fractions.intersection(file_fractions):
                raise ValueError(f'{path}: fraction_id occurs in multiple input tables')
            fractions.update(file_fractions)

    with open(args.output, 'w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter='\t')
        writer.writeheader()
        writer.writerows(rows)
    print(f'Merged {len(rows)} linked channel rows from {len(fractions)} fractions')


if __name__ == '__main__':
    main()
