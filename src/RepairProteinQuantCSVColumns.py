"""Restore OpenMS 3.5 peptide CSV fields omitted for absent plexes.

ProteinQuantifier writes one abundance header per consensusXML channel but can
omit a whole plex's values in a peptide row when that peptide was not observed
there. Use the resolved map to place shortened rows; fail if the placement is
ambiguous rather than shifting intensities into another plex's columns.
"""
import argparse
import csv
from collections import defaultdict
import re

from pyopenms import ConsensusMap, ConsensusXMLFile


ABUNDANCE_HEADER = re.compile(r'abundance\|(.+)\|ch[0-9]+$')


def text(value):
    """Convert pyOpenMS string values to Python text."""
    return value.decode() if isinstance(value, bytes) else str(value)


def plex_columns(header, consensus):
    """Check CSV abundance columns against the map's ordered plex headers."""
    if header[:4] != ['peptide', 'protein', 'n_proteins', 'charge'] or header[-1] != 'fraction':
        raise ValueError('Expected ProteinQuantifier best-charge peptide CSV columns')
    abundance = header[4:-1]
    names = []
    for name in abundance:
        match = ABUNDANCE_HEADER.fullmatch(name)
        if match is None:
            raise ValueError(f'Unexpected peptide abundance header: {name}')
        names.append(match.group(1))
    map_headers = consensus.getColumnHeaders()
    if sorted(map_headers) != list(range(len(abundance))):
        raise ValueError('ConsensusXML channel indices do not match CSV positions')
    if names != [text(map_headers[i].filename) for i in range(len(abundance))]:
        raise ValueError('Peptide CSV and consensusXML plex columns differ')
    columns = {}
    for index, plex in enumerate(names):
        columns.setdefault(plex, []).append(index)
    if any(indices != list(range(indices[0], indices[-1] + 1))
           for indices in columns.values()):
        raise ValueError('Peptide CSV plex columns must be contiguous')
    return columns


def peptide_plexes(consensus):
    """Index the plexes containing each resolved peptide and charge."""
    headers = consensus.getColumnHeaders()
    result = defaultdict(set)
    for feature in consensus:
        plexes = {text(headers[handle.getMapIndex()].filename)
                  for handle in feature.getFeatureList()}
        for identification in feature.getPeptideIdentifications():
            for hit in identification.getHits():
                result[(text(hit.getSequence().toString()), hit.getCharge())].update(plexes)
    return result


def main():
    """Write a full-width peptide CSV with zeros for omitted plex blocks."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input-csv', required=True)
    parser.add_argument('--consensus-xml', required=True)
    parser.add_argument('--output-csv', required=True)
    args = parser.parse_args()

    consensus = ConsensusMap()
    ConsensusXMLFile().load(args.consensus_xml, consensus)
    assignments = peptide_plexes(consensus)
    repaired = 0
    with open(args.input_csv, newline='', encoding='utf-8') as source, \
            open(args.output_csv, 'w', newline='', encoding='utf-8') as target:
        while True:
            position = source.tell()
            line = source.readline()
            if not line or not line.startswith('#'):
                source.seek(position)
                break
            target.write(line)
        reader = csv.reader(source, delimiter='\t')
        writer = csv.writer(target, delimiter='\t', lineterminator='\n')
        header = next(reader)
        columns = plex_columns(header, consensus)
        writer.writerow(header)
        expected_width = len(header)
        for line_number, row in enumerate(reader, start=2):
            if len(row) != expected_width:
                if len(row) < 5:
                    raise ValueError(f'CSV row {line_number} has too few fields')
                key = (row[0], int(row[3]))
                observed_plexes = assignments.get(key, set())
                observed_values = row[4:-1]
                expected_values = sum(len(columns[plex]) for plex in observed_plexes)
                if not observed_plexes or len(observed_values) != expected_values:
                    raise ValueError(f'CSV row {line_number}: cannot place '
                                     f'{len(observed_values)} values for peptide/charge {key}; '
                                     f'consensusXML indicates plexes {sorted(observed_plexes)}')
                values = iter(observed_values)
                repaired_values = []
                for plex, indices in columns.items():
                    if plex in observed_plexes:
                        repaired_values.extend(next(values) for _ in indices)
                    else:
                        repaired_values.extend('0' for _ in indices)
                row = row[:4] + repaired_values + row[-1:]
                repaired += 1
            writer.writerow(row)
    print(f'Restored omitted plex columns in {repaired} peptide rows')


if __name__ == '__main__':
    main()
