""" Rename the filename attributes of a consensusXML file's column headers. """
import argparse
from pyopenms import ConsensusXMLFile, ConsensusMap, ColumnHeader


def parse_args():
    """ parse args """
    parser = argparse.ArgumentParser(prog='ConsensusXMLFileRenamer')
    parser.add_argument(
        '-i', '--input-path',
        type=str,
        help="Input file path. Valid format: ['.consensusXML']"
    )
    parser.add_argument(
        '-o', '--output-path',
        type=str,
        help="Output file path. Valid format: ['.consensusXML']"
    )
    parser.add_argument(
        '--filename',
        type=str,
        help='Filename to set.'
    )
    return parser.parse_args()

def main():
    """ Main entrance """
    args = parse_args()
    input_path:str = args.input_path
    output_path:str = args.output_path
    filename:str = args.filename

    cmap = ConsensusMap()
    ConsensusXMLFile().load(input_path, cmap)
    headers = {}
    for index, header in cmap.getColumnHeaders().items():
        new_header = ColumnHeader(header)
        new_header.filename = filename
        headers[index] = new_header

    cmap.setColumnHeaders(headers)

    ConsensusXMLFile().store(output_path, cmap)

if __name__ == '__main__':
    main()
