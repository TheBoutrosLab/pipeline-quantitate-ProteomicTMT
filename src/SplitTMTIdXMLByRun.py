"""Extract identifications belonging to one mzML run from a plex idXML."""
import argparse
from pathlib import Path
from pyopenms import IdXMLFile

try:
    from pyopenms import PeptideIdentificationList
except ImportError:
    PeptideIdentificationList = list


def text(value):
    """Normalize OpenMS string values."""
    return value.decode() if isinstance(value, bytes) else str(value)


def main():
    """Select PSMs using ProteinIdentification primary paths and id_merge_index."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--input-idxml', required=True)
    parser.add_argument('--mzml', required=True)
    parser.add_argument('--output-idxml', required=True)
    args = parser.parse_args()
    proteins, peptides = [], PeptideIdentificationList()
    IdXMLFile().load(args.input_idxml, proteins, peptides)
    paths = {}
    for protein in proteins:
        runs = []
        protein.getPrimaryMSRunPath(runs)
        paths[protein.getIdentifier()] = [text(run) for run in runs]
    selected = PeptideIdentificationList()
    target = Path(args.mzml).stem
    for pid in peptides:
        runs = paths.get(pid.getIdentifier(), [])
        index = (int(pid.getMetaValue('id_merge_index'))
                 if pid.metaValueExists('id_merge_index') else 0)
        if index >= len(runs):
            raise ValueError(f'Invalid id_merge_index {index} for {pid.getIdentifier()}')
        if Path(runs[index]).stem == target:
            pid.setMetaValue('id_merge_index', 0)
            if hasattr(selected, 'push_back'):
                selected.push_back(pid)
            else:
                selected.append(pid)
    if len(selected) == 0:
        raise ValueError(f'No PSMs in {args.input_idxml} matched {args.mzml}')
    for protein in proteins:
        protein.setPrimaryMSRunPath([args.mzml.encode()], False)
    IdXMLFile().store(args.output_idxml, proteins, selected)
    print(f'Selected {len(selected)} PSMs for {args.mzml}')


if __name__ == '__main__':
    main()
