""" Remove consensus features with identification info resulted from mapping
to a idXML file. """
import argparse
from pyopenms import ConsensusMap, ConsensusXMLFile, DataProcessing, DateTime

try:
    from pyopenms import PeptideIdentificationList
except ImportError:
    PeptideIdentificationList = list


PROG_NAME = 'ConsensusIDRemover'
VERSION = '0.0.1'

class ConsensusIDRemover():
    """ ConsensusIDRemover """
    def __init__(self):
        """ Constructor """
        self.input_path:str = None
        self.output_path:str = None
        self.args:argparse.ArgumentParser = None
        self.cmap = ConsensusMap()
        self.cmap_filtered:ConsensusMap = None

    def parse_args(self):
        """ parse args """
        parser = argparse.ArgumentParser(prog=PROG_NAME)
        parser.add_argument(
            '--input-path',
            type=str,
            help="Path to the input file. Valid format: ['.consensusXML']"
        )
        parser.add_argument(
            '--output-path',
            type=str,
            help="Path to the output file. Valid format: ['.consensusXML']"
        )

        args = parser.parse_args()
        self.args = args
        self.input_path = args.input_path
        self.output_path = args.output_path

    def add_data_processing(self):
        """ add DataProcessing """
        dp = DataProcessing()
        # 11 is for 'FILTERING', from 'DataProcessing.h'
        dp.setProcessingActions({11})
        software = dp.getSoftware()
        software.setName(PROG_NAME)
        software.setVersion(VERSION)

        dp.setSoftware(software)
        dp.setCompletionTime(DateTime().now())

        # pylint: disable=W0212
        for k,v in self.args._get_kwargs():
            dp.setMetaValue(f"parameter: {k}", v)

        data_processing = self.cmap_filtered.getDataProcessing()
        data_processing.append(dp)

        self.cmap_filtered.setDataProcessing(data_processing)

    def main(self):
        """ main """
        self.parse_args()
        ConsensusXMLFile().load(self.input_path, self.cmap)
        print(f"Number of spectra loaded: {self.cmap.size()}", flush=True)

        self.cmap_filtered = ConsensusMap(self.cmap)
        self.cmap_filtered.clear(False)
        self.cmap_filtered.setProteinIdentifications([])
        self.cmap_filtered.setUnassignedPeptideIdentifications(PeptideIdentificationList())

        self.add_data_processing()

        for cf in self.cmap:
            if not cf.getPeptideIdentifications():
                self.cmap_filtered.push_back(cf)

        self.cmap_filtered.ensureUniqueId()

        ConsensusXMLFile().store(self.output_path, self.cmap_filtered)

        print(f"Number of spectra saved: {self.cmap_filtered.size()}", flush=True)

if __name__ == '__main__':
    ConsensusIDRemover().main()
