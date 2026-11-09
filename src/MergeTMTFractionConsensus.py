"""Append linked TMT fractions while retaining plex-specific channel headers."""
from __future__ import annotations
from typing import TYPE_CHECKING
import argparse

from pyopenms import ConsensusMap, ConsensusXMLFile

if TYPE_CHECKING:
    from pyopenms import ColumnHeader

def text(value):
    """Normalize OpenMS string values."""
    return value.decode() if isinstance(value, bytes) else str(value)


def header_signature(headers: dict[int, ColumnHeader]) -> dict[int, tuple[str, str, int]]:
    """Describe the plex and channel represented by each map index."""
    return {
        index: (
            text(header.filename),
            text(header.label),
            int(header.getMetaValue('channel_id'))
        )
        for index, header in headers.items()
    }


def remember_feature_ids(consensus):
    """Keep the per-fraction ID when OpenMS repairs duplicate IDs on merge."""
    for index, feature in enumerate(consensus):
        feature.setMetaValue('tmt_source_linked_feature_id', str(feature.getUniqueId()))
        consensus[index] = feature


def main():
    """Merge fractions only when their channel columns have identical meaning."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--inputs', nargs='+', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()

    reader = ConsensusXMLFile()
    merged = ConsensusMap()
    reader.load(args.inputs[0], merged)
    if merged.getExperimentType() != 'labeled_MS2':
        raise ValueError('Linked TMT fractions must have labeled_MS2 experiment type')
    remember_feature_ids(merged)
    first_headers = merged.getColumnHeaders()
    expected = header_signature(first_headers)
    if not expected:
        raise ValueError('First linked fraction has no reporter channel headers')
    for path in args.inputs[1:]:
        fraction = ConsensusMap()
        reader.load(path, fraction)
        if fraction.getExperimentType() != 'labeled_MS2':
            raise ValueError(f'{path}: expected labeled_MS2 experiment type')
        if header_signature(fraction.getColumnHeaders()) != expected:
            raise ValueError(f'{path}: plex/channel column order differs from the first fraction')
        remember_feature_ids(fraction)
        merged.appendRows(fraction)

    # OpenMS appendRows replaces header filenames with mergedConsensusXMLFile.
    # Restore the plex IDs so ProteinQuantifier keeps plexes as separate assays.
    headers = merged.getColumnHeaders()
    for index, header in headers.items():
        header.filename = first_headers[index].filename
    merged.setColumnHeaders(headers)
    reader.store(args.output, merged)
    print(f'Merged {len(args.inputs)} linked fractions into {args.output}')


if __name__ == '__main__':
    main()
