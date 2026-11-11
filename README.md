# pipeline-quantitate-ProteomicTMT

[![Prepare release](https://img.shields.io/badge/Action-Create%20New%20Release-blue)](https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicTMT/actions/workflows/prepare-release.yaml)

- [pipeline-quantitate-ProteomicTMT](#pipeline-quantitate-proteomictmt)
  - [Overview](#overview)
  - [How To Run](#how-to-run)
  - [Pipeline Steps](#pipeline-steps)
  - [Feature-based TMT workflow](#feature-based-tmt-workflow)
  - [Inputs](#inputs)
    - [Input CSV](#input-csv)
    - [Channel CSV](#channel-csv)
    - [Config](#config)
  - [Outputs](#outputs)
  - [References](#references)
  - [License](#license)

## Overview

This Nextflow DSL2 pipeline quantifies peptides from one or more separate TMT plexes in a single run. Each plex has its own reporter channels and idXML. A plex can start from one or more mzML files or one premerged consensusXML. Both workflows publish one dataset-level consensusXML and one dataset-level peptide CSV. The feature-based workflow also publishes a linked-feature TSV.

![TMT scan-based and feature-based workflow schematic](img/flow-diagram.svg?raw=true)

---

## How To Run

1. Create a `.config` using the [template](config/template.config). Set `dataset_id`, `output_dir`, `idXML_csv`, `mzML_csv`, and `channel_csv`. For premerged input, set `consensusXML_entrypoint = true` and use `consensusXML_csv` in place of `mzML_csv` and `channel_csv`. The entry-point flag selects which source CSV is read. Choose a normalization method for the run.

2. Create an [mzML CSV](input/mzML.csv) or [consensusXML CSV](input/consensusXML.csv), plus an [idXML CSV](input/idXML.csv). Use one mzML row per fraction or one consensusXML row per plex. Feature-based TMT additionally requires `fraction_id` in the mzML CSV. For mzML input, supply one [channel CSV](input/channel.csv) with rows keyed by plex ID. Use one idXML row per plex.

3. Initialize the Git submodules and run the pipeline with Nextflow, for example:

   ```bash
   export NXF_VER=24.10.6
   export NXF_SYNTAX_PARSER=v1
   nextflow run TheBoutrosLab/pipeline-quantitate-ProteomicTMT -r <version> -c config/my-run.config
   ```

   The configuration defaults to Docker. Use `-profile apptainer` or `-profile singularity` where appropriate; the `local` profile uses installed executables for development. The [`.env-template`](.env-template) records the Nextflow version used with the shared configuration modules.

> :warning: mzML files within one plex must have distinct basenames and distinct native scan IDs wherever they have identifications. A premerged consensusXML must retain its column headers and scan identifiers for ID mapping.

---

## Pipeline Steps

For each mzML plex, `FileFilter` sorts its files, `IsobaricAnalyzer` extracts its reporter ions, and `FileMerger` appends its consensus features. The pipeline sets that plex's merged column filenames to its `plex_id`. A premerged plex starts with its supplied consensusXML. After ID mapping within each plex, `FileMerger -append_method append_cols` combines the plexes into one dataset consensusXML while retaining separate channel columns.

Normalization is enabled by default and uses one method across the run. The default `tmt_normalization_method = 'openms'` uses IsobaricAnalyzer's median-ratio normalization; all plexes must then use mzML input. Set it to `mad` to run MSPtools MADNormalizer 1.1.1 once on the final merged dataset consensusXML, before conflict resolution and peptide quantification. The command uses `--layout scan` for scan-based maps and `--layout linked` for feature-based maps. MAD normalization can use a physical reference identified by a column description of `reference`, or a virtual reference computed from reporter intensities. With `MADNormalizer.quasi_intensity = true` (default), MADNormalizer writes reference-scaled quasi-intensities; set it to `false` for normalized log2 ratios. NaN reporter handles are retained by default so missing channels keep their positions in the peptide CSV. Set `enable_tmt_normalization = false` to skip both normalization methods.

Before `IDMapper`, the pipeline aligns a temporary idXML copy's run names to the consensusXML column filename. After the dataset merge, `IDConflictResolver` retains one best-scoring peptide identification and hit per feature so `ProteinQuantifier` can use unambiguous assignments. The pre-resolution and conflict-resolved consensusXMLs are both published so the feature-attached identifications can be inspected before and after selection. The peptide CSV uses the resolved map. OpenMS 3.6 writes all file/channel columns in detailed rows, including zeros for plexes where a peptide was not observed. For OpenMS normalization or MAD quasi-intensity output, MSPtools marks all-zero plexes as missing in the final CSV. It also checks unquantified reporter channels against the consensusXML when `ProteinQuantifier.best_charge = true`. MAD log2-ratio output skips this cleanup because zero denotes equality to the reference, not missing abundance. Set `remove_mapped_consensus = true` to retain unmapped features under `intermediate/` when `save_intermediate_files = true`.

---

## Feature-based TMT workflow

Set `tmt_workflow = 'feature_based'` and `consensusXML_entrypoint = false` to select the optional MS1 feature-based workflow. For normalization, set `tmt_normalization_method = 'mad'`; the default `openms` method is not valid with this workflow. IsobaricAnalyzer normalization stays off to preserve reporter-ion proportions used for channel-area allocation. It estimates TMT channel areas from each integrated MS1 feature and the reporter-ion proportions of its matched PSMs. These estimates should be treated as experimental until validated against benchmark data. Bridge scaling is off by default. The default `tmt_workflow = 'scan_based'` uses the reporter-based peptide workflow.

For this workflow, add `fraction_id` to `mzML.csv`. Each `plex_id` must have one mzML per `fraction_id`, and every plex must have the same set of fraction IDs. One validated idXML still covers all mzML files for a plex. The pipeline splits those identifications by source run, finds MS1 features with `FeatureFinderIdentification`, aligns corresponding fractions across plexes with `MapAlignerIdentification`, and extracts reporter ions from each run with `IsobaricAnalyzer`. After `IDMapper`, it matches reporter scans to FFId PSMs by native scan reference. A custom step sums reporter intensities over a feature's matched scans and assigns channel area as `feature MS1 area × channel reporter sum / total reporter sum`. Scans assigned to multiple features or with conflicting peptide sequences stop the run. Missing reporter channels remain missing.

After linking plexes within each fraction, the feature-based workflow merges those linked maps across all fractions into `${dataset_id}_FeatureBased.consensusXML`. It verifies that the channel columns represent the same plexes and labels in every fraction and preserves the original plex filenames for `ProteinQuantifier`. `IDConflictResolver` and `ProteinQuantifier` then write one `${dataset_id}_ProteinQuantifier_peptide.csv` containing the MS1-scaled channel-area estimates across all plexes and fractions. `ProteinQuantifier.best_charge` controls detailed peptide rows by charge and fraction; the default is `true`. With MAD enabled, normalization runs on the merged feature map before these steps.

The current merges reuse one set of plex/channel headers across source fractions. ProteinQuantifier therefore sees one design fraction per plex in the dataset peptide CSV; its `fraction` column does not identify the input `fraction_id`. The feature-based linked-feature TSV retains the input fraction IDs. This OpenMS upgrade keeps that layout.

Both dataset consensusXML versions and a combined `${dataset_id}_LinkedFeatures.tsv` are published in the final `output/` directory. Each fraction's linked consensusXML and TSV are kept under `intermediate/feature_based/` only when `save_intermediate_files = true`. `FeatureLinkerUnlabeledQT -keep_subelements` retains each plex's TMT channel handles.

Cross-plex linking uses peptide identifications when both features have them, with configurable aligned RT (100 seconds by default) and MS1 m/z (10 ppm) limits; unidentified features can still link by RT, m/z, and charge.

The post-link step matches stable channel-handle IDs to the per-run values and writes each plex's MS1 area and reporter sums as namespaced consensus-element metadata and TSV rows. The combined table preserves `fraction_id`, `plex_id`, reporter `channel_label`, and channel-description `sample_name` on every row. `merge_TMTFeatureTables` concatenates the fraction tables without summing measurements and reconciles `linked_feature_id` with the final consensusXML if OpenMS changes duplicate IDs during fraction merging. Per-run `*.feature-tmt-qc.tsv` files report matched scan counts and reporter totals; `*.feature-tmt-scan-assignment.tsv` files list identified reporter scans and their assigned feature IDs. These, and the per-run value sidecars, are optional intermediate diagnostics. Channel descriptions and plex identity remain in the consensusXML column headers. The feature-based pre-resolution map contains PSMs attached to FFId features; it does not include every PSM from the input idXML. With MAD enabled, the linked table also contains `normalized_channel_area` and `plex_scale_factor`; `estimated_channel_area` remains the original allocation. The final output includes `${dataset_id}_MADNormalizer.consensusXML` and `${dataset_id}_MADNormalizer_scaling.tsv`. Optional `MADNormalizer.bridge_scale = true` aligns each plex’s median of all positive finite reference areas to the median of the plex medians. This uses all positive finite reference areas in each plex, without requiring the same features in every plex. It requires quasi-intensity output. With a physical bridge, the reference sample should be shared across plexes; with a virtual reference, set `MADNormalizer.allow_virtual_bridge = true` and assume comparable overall sample composition. The D’Angelo feature-based test uses a median virtual reference and enables bridge scaling as a technical workflow check. Channel 126 is labeled as a sample in this test and participates in each feature’s virtual reference.

---

## Inputs

### mzML CSV

With `consensusXML_entrypoint = false` (default), use `mzML_csv`. It has one row per mzML fraction. Rows with the same `plex_id` belong to one plex. Set the shared reporter type once with `plex_type` in the run config.

| Field | Required | Description |
| ----- | -------- | ----------- |
| `plex_id` | yes | Unique plex identifier using letters, digits, dots, underscores, or hyphens. |
| `mzML` | yes | Absolute path to this fraction's mzML. |
| `fraction_id` | feature-based only | Identifier for corresponding fractions across plexes; unique within a plex. |
| `correction_matrix` | optional | Isotope-correction rows passed to IsobaricAnalyzer; applies to mzML input. |

```csv
plex_id,mzML
plex_01,/data/plex_01_fraction_1.mzML
plex_01,/data/plex_01_fraction_2.mzML
```

For feature-based TMT, add the matching fraction IDs:

```csv
plex_id,fraction_id,mzML
plex_01,F1,/data/plex_01_fraction_1.mzML
plex_02,F1,/data/plex_02_fraction_1.mzML
```

Use [input/mzML.csv](input/mzML.csv) as a template. Paths must be accessible to Nextflow and the configured containers.

### consensusXML CSV

With `consensusXML_entrypoint = true`, use `consensusXML_csv`. It has exactly one `consensusXML` path per `plex_id` and requires no channel CSV; channel descriptions must already be in the consensusXML headers.

```csv
plex_id,consensusXML
plex_01,/data/plex_01.consensusXML
plex_02,/data/plex_02.consensusXML
```

Use [input/consensusXML.csv](input/consensusXML.csv) as a template.

### idXML CSV

The idXML CSV has exactly one row per plex. Its `plex_id` values must match the chosen source CSV exactly, including for a multi-fraction plex.

```csv
plex_id,idXML
plex_01,/data/plex_01.idXML
plex_02,/data/plex_02.idXML
```

Use [input/idXML.csv](input/idXML.csv) as a template.

### Channel CSV

For mzML input, provide one `channel_csv` containing every plex's reporter channels. Its `plex_id` values must match the mzML CSV exactly. The pipeline groups these rows by plex ID and passes only that plex's channels to IsobaricAnalyzer. Reporter labels must match the run's `plex_type`. Sample names belong in the `description` column. Label one channel per plex `reference` when using OpenMS normalization or MAD normalization with a physical reference; its reporter label is passed to IsobaricAnalyzer. MAD normalization with a virtual reference does not require this label.

| Field | Required | Description |
| ----- | -------- | ----------- |
| `plex_id` | yes | Plex identifier matching the mzML and idXML CSVs. |
| `channel` | yes | Reporter label, such as `126` or `127N` for TMT10plex. |
| `description` | yes | Channel identifier; use `reference` for a physical MAD reference. |

```csv
plex_id,channel,description
plex_01,126,reference
plex_01,127N,sample_01
plex_02,126,reference
plex_02,127N,sample_02
```

Use [input/channel.csv](input/channel.csv) as a channel CSV template.

A premerged consensusXML must already contain channel descriptions in its column headers.

### Config

| Parameter | Type | Description |
| --------- | ---- | ----------- |
| `consensusXML_entrypoint` | bool | Select the premerged consensusXML entry point. Defaults to `false` (mzML). |
| `mzML_csv` | string(path) | mzML fractions; required when `consensusXML_entrypoint = false`. |
| `channel_csv` | string(path) | Reporter channels and sample descriptions keyed by plex ID; required for mzML input. |
| `plex_type` | string | OpenMS reporter type shared by all plexes; required for mzML input. |
| `consensusXML_csv` | string(path) | One premerged consensusXML per plex; required when `consensusXML_entrypoint = true`. |
| `idXML_csv` | string(path) | Required CSV with one idXML path per plex. |
| `output_dir` | string(path) | Root output directory. |
| `dataset_id` | string | Required dataset identifier used in final filenames; letters, digits, dots, underscores, and hyphens only. |
| `enable_tmt_normalization` | bool | Enable the selected normalization method. Defaults to `true`. |
| `tmt_normalization_method` | string | `openms` (default) or `mad`; OpenMS normalization requires every plex to use mzML input. |
| `MADNormalizer.virtual_reference` | bool | Have MADNormalizer derive a reference from each feature's reporter intensities. Defaults to `false`. |
| `MADNormalizer.virtual_reference_method` | string | `median` or `mean` for a virtual MAD reference. MSPtools defaults to `median`. |
| `MADNormalizer.virtual_reference_min_channels` | integer | Minimum valid channels per feature and plex for a virtual reference. Defaults to `1`; channels must be finite and above `MADNormalizer.min_int`. |
| `MADNormalizer.quasi_intensity` | bool | Write reference-scaled quasi-intensities instead of log2 ratios for MAD. Defaults to `true`. |
| `MADNormalizer.bridge_scale` | bool | Scale feature-based plexes by their median valid reference areas. Defaults to `false`. |
| `MADNormalizer.allow_virtual_bridge` | bool | Explicitly allow bridge scaling with virtual references. Defaults to `false`. |
| `filter_na_consensus_handles` | bool | Remove NaN reporter handles after MAD normalization. Defaults to `false` to preserve CSV columns. |
| `ProteinQuantifier.best_charge` | bool | Report detailed peptide abundances by charge and fraction. Defaults to `true`. |
| `ProteinQuantifier.fractions.aggregate` | string | Combine fractions for assay-level abundances; defaults to `sum`. Detailed peptide rows remain separate. |
| `tmt_workflow` | string | Select `scan_based` (default) or `feature_based`. The feature-based workflow requires mzML input and `fraction_id`; normalization requires `tmt_normalization_method = mad`. |
| `remove_mapped_consensus` | bool | Also publish the consensusXML of unmapped features. Defaults to `false`. |
| `save_intermediate_files` | bool | Publish intermediate files. Defaults to `false`. |
| `resource_allocation_profile_tag` | string | Resource profile in `config/resources.json`. Defaults to `default`. |
| `base_resource_update` | namespace | Optional per-process CPU and memory adjustments using the shared resource handler. |
| `work_dir` | string(path) | Optional Nextflow work directory. |

Additional OpenMS and MSPtools options and their pipeline parameter names are listed in [docs/params.rst](docs/params.rst). The default OpenMS image uses 3.6.0; the pyOpenMS image remains at 3.5.0. The default MSPtools image is 1.1.1, which supports merged scan and linked maps and a configurable virtual-reference channel threshold.

---

## Outputs

Final results are saved under `<output_dir>/quantitate-ProteomicTMT-<version>/OpenMS-<version>/output/`. Replace `${dataset_id}` below with the configured dataset identifier:

| Workflow | Output | Description |
| --- | --- | --- |
| Scan-based | `${dataset_id}_ScanBased.consensusXML` | Merged plex map before peptide-identification conflict resolution. |
| Feature-based | `${dataset_id}_FeatureBased.consensusXML` | Linked feature map before peptide-identification conflict resolution. |
| Feature-based | `${dataset_id}_LinkedFeatures.tsv` | Linked feature/channel rows from all fractions and plexes; includes `fraction_id`, `plex_id`, and `sample_name`. |
| Both | `${dataset_id}_IDConflictResolver.consensusXML` | Dataset map after resolving conflicting identifications. |
| Both | `${dataset_id}_ProteinQuantifier_peptide.csv` | Peptide quantification when normalization is disabled. |
| Both with OpenMS normalization or MAD quasi-intensities | `${dataset_id}_ProteinQuantifier_peptide_fixZeroPlex.csv` | Final peptide quantification after missing-value cleanup. |
| Both with MAD log2 ratios | `${dataset_id}_ProteinQuantifier_peptide.csv` | Peptide table; zero ratios remain zero. |

Plex and fraction maps, per-run feature allocation tables, and scan-assignment/QC reports are published under `intermediate/` only when `save_intermediate_files = true`. Process logs and Nextflow reports are written under the timestamped `log-quantitate-ProteomicTMT-*` directory. Four NFTest integration cases are defined in [nftest.yml](nftest.yml); fixture setup is described in [test/README.md](test/README.md).

---

## References

1. Pfeuffer et al. OpenMS 3 enables reproducible analysis of large-scale mass spectrometry data. *Nature Methods*, 21, 365–367 (2024). [doi:10.1038/s41592-024-02197-7](https://doi.org/10.1038/s41592-024-02197-7)
2. [MSPtools](https://github.com/TheBoutrosLab/package-MSPtools), used for MAD normalization and peptide CSV cleanup.

---

## License

pipeline-quantitate-ProteomicTMT is licensed under the GNU General Public License version 2. See [LICENSE](LICENSE) for the terms of the GNU GPL license.

Copyright (C) 2026 Sanford Burnham Prebys Medical Discovery Institute ("Boutros Lab")

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
