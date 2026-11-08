# pipeline-quantitate-ProteomicTMT

[![Prepare release](https://img.shields.io/badge/Action-Create%20New%20Release-blue)](https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicTMT/actions/workflows/prepare-release.yaml)

- [pipeline-quantitate-ProteomicTMT](#pipeline-quantitate-proteomictmt)
  - [Overview](#overview)
  - [How To Run](#how-to-run)
  - [Pipeline Steps](#pipeline-steps)
  - [Inputs](#inputs)
    - [Input CSV](#input-csv)
    - [Channel CSV](#channel-csv)
    - [Config](#config)
  - [Outputs](#outputs)
  - [References](#references)
  - [License](#license)

## Overview

This Nextflow DSL2 pipeline quantifies peptides from one or more separate TMT plexes in a single run. Each plex has its own reporter channels and idXML. A plex can start from one or more mzML files or one premerged consensusXML. The pipeline publishes peptide results separately for each plex; cross-plex peptide integration belongs in quantitate-ProteomicProtein.

---

## How To Run

1. Create a `.config` using the [template](config/template.config). Set `output_dir`, `idXML_csv`, `mzML_csv`, and `channel_csv`. For premerged input, set `consensusXML_entrypoint = true` and use `consensusXML_csv` in place of `mzML_csv` and `channel_csv`. The entry-point flag selects which source CSV is read. Choose a normalization method for the run.

2. Create an [mzML CSV](input/mzML.csv) or [consensusXML CSV](input/consensusXML.csv), plus an [idXML CSV](input/idXML.csv). Use one mzML row per fraction or one consensusXML row per plex. For mzML input, supply one [channel CSV](input/channel.csv) with rows keyed by plex ID. Use one idXML row per plex.

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

For each mzML plex, `FileFilter` sorts its files, `IsobaricAnalyzer` extracts its reporter ions, and `FileMerger` appends its consensus features. The pipeline sets that plex's merged column filenames to its `plex_id`. A premerged plex starts with its supplied consensusXML. Plex IDs stay attached to every downstream process, so files from separate plexes do not merge.

Normalization is enabled by default and uses one method across the run. The default `tmt_normalization_method = 'openms'` uses IsobaricAnalyzer's median-ratio normalization; all plexes must then use mzML input. Set it to `mad` to use MSPtools MADNormalizer independently on each plex after merging. MAD normalization can use a physical reference identified by a column description of `reference`, or a virtual reference computed from reporter intensities. With `mad_normalizer_quasi_intensity = true` (default), MADNormalizer writes reference-scaled quasi-intensities; set it to `false` for normalized log2 ratios. NaN reporter handles are retained by default so missing channels keep their positions in the peptide CSV. Set `enable_tmt_normalization = false` to skip both normalization methods.

Before `IDMapper`, the pipeline aligns a temporary idXML copy's run names to the consensusXML column filename. `IDConflictResolver` resolves mapped peptide assignments, and `ProteinQuantifier` writes peptide abundances. When normalization is enabled, MSPtools marks all-zero plexes as missing in the final CSV. It also checks unquantified reporter channels against the consensusXML when `protein_quantifier_best_charge_and_fraction = true`. Set `remove_mapped_consensus = true` to also publish unmapped features.

---

## Inputs

### mzML CSV

With `consensusXML_entrypoint = false` (default), use `mzML_csv`. It has one row per mzML fraction. Rows with the same `plex_id` belong to one plex. Set the shared reporter type once with `plex_type` in the run config.

| Field | Required | Description |
| ----- | -------- | ----------- |
| `plex_id` | yes | Unique plex identifier using letters, digits, dots, underscores, or hyphens. |
| `mzML` | yes | Absolute path to this fraction's mzML. |
| `correction_matrix` | optional | Isotope-correction rows passed to IsobaricAnalyzer; applies to mzML input. |

```csv
plex_id,mzML
plex_01,/data/plex_01_fraction_1.mzML
plex_01,/data/plex_01_fraction_2.mzML
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
| `enable_tmt_normalization` | bool | Enable the selected normalization method. Defaults to `true`. |
| `tmt_normalization_method` | string | `openms` (default) or `mad`; OpenMS normalization requires every plex to use mzML input. |
| `virtual_reference` | bool | Have MADNormalizer derive a reference from each feature's reporter intensities. Defaults to `false`. |
| `virtual_reference_method` | string | `median` or `mean` for a virtual MAD reference. MSPtools defaults to `median`. |
| `mad_normalizer_quasi_intensity` | bool | Write reference-scaled quasi-intensities instead of log2 ratios for MAD. Defaults to `true`. |
| `filter_na_consensus_handles` | bool | Remove NaN reporter handles after MAD normalization. Defaults to `false` to preserve CSV columns. |
| `protein_quantifier_best_charge_and_fraction` | bool | Report peptide abundances by charge and fraction. Defaults to `true`. |
| `remove_mapped_consensus` | bool | Also publish the consensusXML of unmapped features. Defaults to `false`. |
| `save_intermediate_files` | bool | Publish intermediate files. Defaults to `false`. |
| `resource_allocation_profile_tag` | string | Resource profile in `config/resources.json`. Defaults to `default`. |
| `base_resource_update` | namespace | Optional per-process CPU and memory adjustments using the shared resource handler. |
| `work_dir` | string(path) | Optional Nextflow work directory. |

Additional OpenMS and MSPtools options and their pipeline parameter names are listed in [docs/params.rst](docs/params.rst). The default OpenMS and pyOpenMS images use 3.5.0. The default MSPtools image is 1.0.3, which includes MAD quasi-intensity output and the corrected `fixZeroPlex` peptide-charge lookup.

---

## Outputs

Final results are saved under `<output_dir>/quantitate-ProteomicTMT-<version>/OpenMS-<version>/output/<plex_id>/`:

| Output | Description |
| ------ | ----------- |
| `<plex_id>_FileMerger.consensusXML` | Merged reporter-ion features, for mzML input. |
| `<plex_id>_IDMapper.consensusXML` | Consensus features with peptide identifications mapped to them. |
| `<plex_id>_IDConflictResolver.consensusXML` | Consensus features after conflicting identifications are resolved. |
| `<plex_id>_ProteinQuantifier_peptide_fixZeroPlex.csv` | Final peptide abundances when normalization is enabled. |
| `<plex_id>_ProteinQuantifier_peptide.csv` | Final peptide abundances when normalization is disabled. |
| `<plex_id>_unmapped.consensusXML` | Unmapped features, when `remove_mapped_consensus = true`. |

Intermediate files are published under `intermediate/<plex_id>/` when `save_intermediate_files = true`. Process logs and Nextflow reports are written under the timestamped `log-quantitate-ProteomicTMT-*` directory. Three NFTest integration cases are defined in [nftest.yml](nftest.yml); fixture setup is described in [test/README.md](test/README.md).

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
