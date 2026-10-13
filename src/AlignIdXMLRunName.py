"""Align idXML run names with TMT consensusXML columns for IDMapper.

FileMerger's append_rows mode represents one plex using one column filename.
IDMapper matches isobaric features by that filename and the native scan ID.
This script changes only a temporary copy of the idXML used by IDMapper.
"""

import argparse
from pathlib import Path

from pyopenms import ConsensusMap, ConsensusXMLFile, IdXMLFile

try:
    from pyopenms import PeptideIdentificationList
except ImportError:
    # pyOpenMS 3.2 accepts a Python list; the configured 3.5 image requires
    # the typed vector for IdXMLFile.load/store.
    PeptideIdentificationList = list


def as_text(value):
    """Convert pyOpenMS strings, including byte strings, to Python text."""
    return value.decode('utf-8') if isinstance(value, bytes) else str(value)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--consensus-xml', required=True)
    parser.add_argument('--input-idxml', required=True)
    parser.add_argument('--output-idxml', required=True)
    args = parser.parse_args()

    consensus = ConsensusMap()
    ConsensusXMLFile().load(args.consensus_xml, consensus)
    filenames = {
        Path(as_text(header.filename)).name
        for header in consensus.getColumnHeaders().values()
    }
    if not filenames:
        raise ValueError('The consensusXML has no column filenames for ID mapping.')

    proteins = []
    peptides = PeptideIdentificationList()
    IdXMLFile().load(args.input_idxml, proteins, peptides)
    paths_by_identifier = {}
    for protein in proteins:
        paths = []
        protein.getPrimaryMSRunPath(paths)
        if not paths:
            raise ValueError('An idXML identification run has no primary MS run path.')
        paths_by_identifier[protein.getIdentifier()] = [as_text(path) for path in paths]

    if len(filenames) == 1:
        target = next(iter(filenames))
        seen_scans = {}
        for peptide in peptides:
            if not peptide.getHits():
                continue
            scan = as_text(peptide.getMetaValue('spectrum_reference')) if peptide.metaValueExists('spectrum_reference') else ''
            if not scan:
                continue
            paths = paths_by_identifier[peptide.getIdentifier()]
            index = int(peptide.getMetaValue('id_merge_index')) if peptide.metaValueExists('id_merge_index') else 0
            source = paths[index]
            previous = seen_scans.setdefault(scan, source)
            if previous != source:
                raise ValueError(
                    f'Scan ID {scan!r} occurs in both {previous!r} and {source!r}; '
                    'these runs must be mapped separately before merging.'
                )
        if not seen_scans:
            raise ValueError('The idXML contains no identified spectrum references.')
        for protein in proteins:
            paths = paths_by_identifier[protein.getIdentifier()]
            protein.setPrimaryMSRunPath([target.encode('utf-8')] * len(paths), False)
        print(f'Using consensusXML source name {target!r} for {len(seen_scans)} identified scans.')
    else:
        source_names = {Path(path).name for paths in paths_by_identifier.values() for path in paths}
        missing = filenames - source_names
        if missing:
            raise ValueError(f'ConsensusXML column filenames lack matching idXML runs: {sorted(missing)}')
        print('ConsensusXML has distinct source names; idXML run paths already match.')

    IdXMLFile().store(args.output_idxml, proteins, peptides)


if __name__ == '__main__':
    main()
