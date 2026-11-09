TMT command parameters
======================

These keys are read by the current process modules and passed to the indicated command option. OpenMS and MSPTools defaults come from the configured images.


extract_isobaric
----------------

.. list-table::
   :header-rows: 1

   * - Config key or manifest field
     - Command option
     - Kind
   * - Config ``plex_type``
     - ``-type``
     - value
   * - ``isobaric_analyzer_extraction_select_activation``
     - ``-extraction:select_activation``
     - value
   * - ``isobaric_analyzer_extraction_reporter_mass_shift``
     - ``-extraction:reporter_mass_shift``
     - value
   * - ``isobaric_analyzer_extraction_min_precursor_intensity``
     - ``-extraction:min_precursor_intensity``
     - value
   * - ``isobaric_analyzer_extraction_min_reporter_intensity``
     - ``-extraction:min_reporter_intensity``
     - value
   * - ``isobaric_analyzer_extraction_min_precursor_purity``
     - ``-extraction:min_precursor_purity``
     - value
   * - ``isobaric_analyzer_extraction_precursor_isotope_deviation``
     - ``-extraction:precursor_isotope_deviation``
     - value
   * - ``isobaric_analyzer_extraction_keep_unannotated_precursor``
     - ``-extraction:keep_unannotated_precursor``
     - value
   * - ``isobaric_analyzer_quantification_isotope_correction``
     - ``-quantification:isotope_correction``
     - value
   * - ``tmt_normalization_method`` with ``enable_tmt_normalization = true``
     - ``-quantification:normalization`` for ``openms``; omitted otherwise
     - flag
   * - ``isobaric_analyzer_extraction_purity_interpolation``
     - ``-extraction:purity_interpolation``
     - flag
   * - ``isobaric_analyzer_extraction_discard_low_intensity_quantifications``
     - ``-extraction:discard_low_intensity_quantifications``
     - flag


link_TMTFeatures
----------------

.. list-table::
   :header-rows: 1

   * - Config key
     - Command option
     - Kind
   * - ``feature_linker_use_identifications``
     - ``-algorithm:use_identifications``
     - value
   * - ``feature_linker_rt_tolerance``
     - ``-algorithm:distance_RT:max_difference`` (seconds)
     - value
   * - ``feature_linker_mz_tolerance_ppm``
     - ``-algorithm:distance_MZ:max_difference`` with ``-algorithm:distance_MZ:unit ppm``
     - value


fix_ProteinQuantCSV_unquantified
--------------------------------

.. list-table::
   :header-rows: 1

   * - Config key
     - Command option
     - Kind
   * - ``protein_quantifier_format_separator``
     - ``--separator``
     - value
   * - ``protein_quantifier_format_quoting``
     - ``--quoting``
     - value


map_idXML2consensusXML
----------------------

.. list-table::
   :header-rows: 1

   * - Config key
     - Command option
     - Kind
   * - ``id_mapper_rt_tolerance``
     - ``-rt_tolerance``
     - value
   * - ``id_mapper_mz_tolerance``
     - ``-mz_tolerance``
     - value
   * - ``id_mapper_mz_measure``
     - ``-mz_measure``
     - value
   * - ``id_mapper_mz_reference``
     - ``-mz_reference``
     - value
   * - ``id_mapper_feature_use_centroid_rt``
     - ``-feature:use_centroid_rt``
     - value
   * - ``id_mapper_feature_use_centroid_mz``
     - ``-feature:use_centroid_mz``
     - value
   * - ``id_mapper_consensus_use_subelements``
     - ``-consensus:use_subelements``
     - flag
   * - ``id_mapper_consensus_annotate_ids_with_subelements``
     - ``-consensus:annotate_ids_with_subelements``
     - flag


normalize_consensusXML_MAD
--------------------------

.. list-table::
   :header-rows: 1

   * - Config key
     - Command option
     - Kind
   * - ``min_int``
     - ``--min-int``
     - value
   * - ``virtual_reference_method``
     - ``--virtual-reference-method``
     - value
   * - ``virtual_reference_min_channels``
     - ``--virtual-reference-min-channels``
     - value
   * - ``virtual_reference``
     - ``--virtual-reference``
     - flag
   * - ``mad_normalizer_quasi_intensity``
     - ``--quasi-intensity``
     - flag
   * - ``mad_normalizer_bridge_scale``
     - ``--bridge-scale``
     - flag
   * - ``mad_normalizer_allow_virtual_bridge``
     - ``--allow-virtual-bridge``
     - flag

``--layout`` is set from ``tmt_workflow`` (``scan`` or ``linked``), and a
per-plex scaling report is written for every MAD run.


quantify_peptides
-----------------

.. list-table::
   :header-rows: 1

   * - Config key
     - Command option
     - Kind
   * - ``protein_quantifier_format_separator``
     - ``-format:separator``
     - value
   * - ``protein_quantifier_format_quoting``
     - ``-format:quoting``
     - value
   * - ``protein_quantifier_format_replacement``
     - ``-format:replacement``
     - value


resolve_conflict
----------------

.. list-table::
   :header-rows: 1

   * - Config key
     - Command option
     - Kind
   * - ``conflict_resolver_resolve_between_features``
     - ``-resolve_between_features``
     - value


Extraction-specific inputs
--------------------------

The run-level ``plex_type`` sets ``-type`` for every mzML plex. The ``channel_csv`` groups reporter descriptions by ``plex_id``. A row whose description is ``reference`` supplies that plex's ``-reference_channel``; optional ``correction_matrix`` values in ``mzML.csv`` use an option under the reporter type. ``tmt_normalization_method`` selects ``openms`` (default) or ``mad`` for every plex in the run. OpenMS normalization runs in IsobaricAnalyzer and requires mzML input for every plex; MAD normalization runs independently on each plex after consensusXML merging. ``enable_tmt_normalization = false`` skips both. ``protein_quantifier_best_charge_and_fraction`` defaults to true and controls ``-best_charge_and_fraction``. Set it to false to omit the flag.
