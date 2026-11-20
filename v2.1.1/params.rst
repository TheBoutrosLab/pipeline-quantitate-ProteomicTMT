Program parameters
==================

The pipeline reads optional command settings from namespaces named after the
programs. Nested keys become colon-separated options: for example,
``FeatureFinderIdentification.detect.mapping_tolerance`` becomes
``-detect:mapping_tolerance``. Unset keys are omitted, so the configured image
supplies its own default. A numeric zero or a valued ``false`` is passed.
A list value is passed as multiple values for one option. Only the presence-only
options listed below are treated as flags: ``true`` adds
that option and ``false`` omits it. Pipeline-owned input, output, thread, and
reporter-type options should not be placed in these namespaces.

The full option list and version-specific defaults are available from each
configured tool's ``-helphelp`` (OpenMS) or ``--help`` (MSPtools). In OpenMS
3.6, a boolean parameter whose default is ``true`` takes an explicit value;
for example, ``IsobaricAnalyzer.extraction.purity_interpolation = false``
passes ``-extraction:purity_interpolation 'false'``. False-by-default boolean
parameters registered as flags use the presence-only form below.

.. list-table:: Program namespaces
   :header-rows: 1

   * - Config namespace
     - Program
     - Flag keys (all other keys take a value)
   * - ``IsobaricAnalyzer``
     - ``IsobaricAnalyzer``
     - ``extraction.discard_low_intensity_quantifications``
   * - ``FileMerger``
     - ``FileMerger``
     - ``annotate_file_origin``, ``raw.rt_auto``, ``raw.rt_filename``
   * - ``FileFilter``
     - ``FileFilter``
     - ``sort``, ``peak_options.sort_peaks``, ``peak_options.no_chromatograms``,
       ``peak_options.remove_chromatograms``, ``peak_options.remove_empty``,
       ``peak_options.remove_metadataarrays``, ``spectra.remove_zoom``,
       ``spectra.select_zoom``, ``consensus.map_and``, ``f_and_c.remove_hull``,
       ``id.remove_clashes``, ``id.keep_best_score_id``,
       ``id.remove_annotated_features``, ``id.remove_unannotated_features``,
       ``id.remove_unassigned_ids``, ``id.blacklist_imperfect``
   * - ``IDMapper``
     - ``IDMapper``
     - ``ignore_charge``, ``consensus.use_subelements``,
       ``consensus.annotate_ids_with_subelements``
   * - ``ProteinQuantifier``
     - ``ProteinQuantifier``
     - ``best_charge``, ``top.include_all``,
       ``consensus.normalize``, ``consensus.fix_peptides``
   * - ``IDConflictResolver``
     - ``IDConflictResolver``
     - None
   * - ``FeatureFinderIdentification``
     - ``FeatureFinderIdentification``
     - ``svm.no_selection``, ``svm.no_shrinking``, ``quantify_decoys``,
       ``EMGScoring.init_mom``, ``model.unweighted_fit``,
       ``model.no_imputation``, ``model.each_trace``
   * - ``MapAlignerIdentification``
     - ``MapAlignerIdentification``
     - ``store_original_rt``, ``algorithm.score_cutoff``,
       ``algorithm.use_feature_rt``, ``model.linear.symmetric_regression``,
       ``model.lowess.auto_span``
   * - ``FeatureLinkerUnlabeledQT``
     - ``FeatureLinkerUnlabeledQT``
     - ``algorithm.use_identifications``, ``algorithm.ignore_charge``
   * - ``MADNormalizer``
     - ``msptools ConsensusXML MADNormalizer``
     - ``virtual_reference``, ``quasi_intensity``, ``bridge_scale``, ``allow_virtual_bridge``
   * - ``fixZeroPlex``
     - ``msptools ProteinQuantCSV fixZeroPlex``
     - ``greedy_group_resolution``, ``nocheck_intensity``

MSPtools option names use hyphens on the command line, so
``MADNormalizer.virtual_reference_min_channels`` becomes
``--virtual-reference-min-channels``. OpenMS options use colons between nested
levels. For example, ``FeatureLinkerUnlabeledQT.algorithm.distance_MZ.max_difference``
becomes ``-algorithm:distance_MZ:max_difference``.

The pipeline sets defaults for ``IDMapper.consensus`` flags,
``ProteinQuantifier.best_charge`` and ``ProteinQuantifier.fractions.aggregate``,
selected ``MADNormalizer``
options, and the feature linker's identification, RT, and m/z settings in
``config/default.config``. Set other options in a run config only when needed.
For example, the following are optional values supported directly by OpenMS::

    params {
        FeatureFinderIdentification {
            extract { mz_window = 10.0 }
            detect { mapping_tolerance = 0.0 }
            EMGScoring { max_iteration = 100 }
            model { type = 'symmetric' }
        }
        MapAlignerIdentification {
            algorithm { use_feature_rt = true; use_unassigned_peptides = false }
        }
    }

Frequently adjusted valued options
----------------------------------

.. list-table::
   :header-rows: 1

   * - Config path (under ``params``)
     - Command option
   * - ``FeatureFinderIdentification.extract.mz_window``
     - ``-extract:mz_window``
   * - ``FeatureFinderIdentification.detect.peak_width``
     - ``-detect:peak_width``
   * - ``FeatureFinderIdentification.detect.mapping_tolerance``
     - ``-detect:mapping_tolerance``
   * - ``FeatureFinderIdentification.model.type``
     - ``-model:type``
   * - ``FeatureFinderIdentification.EMGScoring.max_iteration``
     - ``-EMGScoring:max_iteration``
   * - ``MapAlignerIdentification.algorithm.use_feature_rt``
     - ``-algorithm:use_feature_rt`` (presence-only flag)
   * - ``MapAlignerIdentification.algorithm.use_unassigned_peptides``
     - ``-algorithm:use_unassigned_peptides`` (valued boolean)
   * - ``MapAlignerIdentification.algorithm.max_rt_shift``
     - ``-algorithm:max_rt_shift``
   * - ``MapAlignerIdentification.model.type``
     - ``-model:type``
   * - ``FeatureLinkerUnlabeledQT.algorithm.use_identifications``
     - ``-algorithm:use_identifications`` (presence-only flag in OpenMS 3.6)
   * - ``FeatureLinkerUnlabeledQT.algorithm.distance_RT.max_difference``
     - ``-algorithm:distance_RT:max_difference`` (seconds)
   * - ``FeatureLinkerUnlabeledQT.algorithm.distance_MZ.max_difference``
     - ``-algorithm:distance_MZ:max_difference`` (unit given by ``algorithm.distance_MZ.unit``)

The pipeline selects IsobaricAnalyzer normalization and the reporter type
from workflow settings. It supplies all program input and output paths and
thread counts. These options are not user overrides.
