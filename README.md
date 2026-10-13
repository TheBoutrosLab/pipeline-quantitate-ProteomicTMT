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

This Nextflow DSL2 pipeline quantifies peptides from one isobaric-labeled TMT plex. It combines reporter-ion measurements with peptide identifications using OpenMS and MSPtools. One run accepts either an mzML CSV plus an idXML, or a premerged consensusXML plus an idXML. The reporter channels are samples within the plex; every mzML row in one run must belong to that plex.

---

## How To Run

1. Create a `.config` using the [template](config/template.config). Set `output_dir`, `plex_name`, `idXML`, and exactly one of `input_csv` or `merged_consensusXML`. For mzML input, also set `channel_description` and review the plex type, reference channel, and normalization method.

2. For mzML input, create an [input CSV](input/input.csv) listing the mzML files and a channel CSV with `channel,description` columns. A premerged consensusXML already contains channel descriptions in its column headers; it does not use either CSV.

3. Initialize the Git submodules and run the pipeline with Nextflow, for example:

   ```bash
   export NXF_VER=24.10.6
   export NXF_SYNTAX_PARSER=v1
   nextflow run TheBoutrosLab/pipeline-quantitate-ProteomicTMT -r <version> -c config/my-run.config
   ```

   The configuration defaults to Docker. Use `-profile apptainer` or `-profile singularity` where appropriate; the `local` profile uses installed executables for development. The [`.env-template`](.env-template) records the Nextflow version used with the shared configuration modules.

> :warning: A single run processes one plex. The merged input must retain its column headers and scan identifiers for ID mapping. Different source files with duplicate native scan IDs must be mapped separately before merging.

---

## Pipeline Steps

For mzML input, `FileFilter` sorts each file, `IsobaricAnalyzer` extracts reporter ions, and `FileMerger` appends the consensus features. The pipeline sets the merged column filenames to `plex_name`. The premerged entry point starts with the supplied consensusXML.

Normalization is enabled by default. The default `tmt_normalization_method = 'openms'` uses IsobaricAnalyzer's median-ratio normalization and requires mzML input. Set it to `mad` to use MSPtools MADNormalizer after merging. MAD normalization can use a physical reference identified by a column description of `reference`, or a virtual reference computed from reporter intensities. With `mad_normalizer_quasi_intensity = true` (default), MADNormalizer writes reference-scaled quasi-intensities; set it to `false` for normalized log2 ratios. NaN reporter handles are retained by default so missing channels keep their positions in the peptide CSV. Set `enable_tmt_normalization = false` to skip both normalization methods.

Before `IDMapper`, the pipeline aligns a temporary idXML copy's run names to the consensusXML column filename. `IDConflictResolver` resolves mapped peptide assignments, and `ProteinQuantifier` writes peptide abundances. When normalization is enabled, MSPtools marks all-zero plexes as missing in the final CSV. It also checks unquantified reporter channels against the consensusXML when `protein_quantifier_best_charge_and_fraction = true`. Set `remove_mapped_consensus = true` to also publish unmapped features.

---

## Inputs

### Input CSV

For the mzML entry point, the CSV has one column and one mzML path per row. All rows belong to the same plex; multiple rows can represent fractions of that plex.

| Field | Required | Description |
| ----- | -------- | ----------- |
| `path` | yes | Absolute path to an mzML file. |

```csv
path
/data/plex_01_fraction_1.mzML
/data/plex_01_fraction_2.mzML
```

Use [input/input.csv](input/input.csv) as a template. For the premerged entry point, set `merged_consensusXML` instead of `input_csv`.

### Channel CSV

The mzML entry point also requires a CSV of reporter-channel labels. The labels must match `isobaric_analyzer_type`. For physical-reference MAD normalization, mark the reference channel with the description `reference`.

| Field | Required | Description |
| ----- | -------- | ----------- |
| `channel` | yes | Reporter label, such as `126` or `127N` for TMT10plex. |
| `description` | yes | Channel identifier; use `reference` for a physical MAD reference. |

```csv
channel,description
126,reference
127N,sample_01
127C,sample_02
```

A premerged consensusXML must already contain channel descriptions in its column headers. The `channel_description` parameter is ignored for that entry point.

### Config

| Parameter | Type | Description |
| --------- | ---- | ----------- |
| `input_csv` | string(path) | mzML CSV. Set this or `merged_consensusXML`, but not both. |
| `merged_consensusXML` | string(path) | Existing merged consensusXML used instead of mzML extraction. |
| `idXML` | string(path) | Peptide identifications matching the supplied spectra. |
| `output_dir` | string(path) | Root output directory. |
| `plex_name` | string | Name of the plex used in output paths and, for mzML input, consensusXML column filenames. |
| `channel_description` | string(path) | Channel CSV required for mzML extraction. |
| `isobaric_analyzer_type` | string | OpenMS reporter-plex type, such as `tmt10plex`. |
| `reference_channel` | string | Reference-channel label passed to IsobaricAnalyzer for mzML input. |
| `correction_matrix` | string | Optional isotope-correction rows passed to IsobaricAnalyzer. |
| `enable_tmt_normalization` | bool | Enable the selected normalization method. Defaults to `true`. |
| `tmt_normalization_method` | string | `openms` (default) or `mad`; OpenMS normalization requires mzML input. |
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

Additional OpenMS and MSPtools options and their pipeline parameter names are listed in [docs/params.rst](docs/params.rst). The default OpenMS and pyOpenMS images use 3.5.0. The default MSPtools image is 1.0.1; MAD quasi-intensity output requires an image containing `--quasi-intensity`, such as the `dev` image used by the integration tests.

---

## Outputs

Final results are saved under `<output_dir>/quantitate-ProteomicTMT-<version>/<plex_name>/OpenMS-<version>/output/`:

| Output | Description |
| ------ | ----------- |
| `<plex_name>_FileMerger.consensusXML` | Merged reporter-ion features, for mzML input. |
| `<plex_name>_IDMapper.consensusXML` | Consensus features with peptide identifications mapped to them. |
| `<plex_name>_IDConflictResolver.consensusXML` | Consensus features after conflicting identifications are resolved. |
| `<plex_name>_ProteinQuantifier_peptide_fixZeroPlex.csv` | Final peptide abundances when normalization is enabled. |
| `<plex_name>_ProteinQuantifier_peptide.csv` | Final peptide abundances when normalization is disabled. |
| `<plex_name>_unmapped.consensusXML` | Unmapped features, when `remove_mapped_consensus = true`. |

Intermediate files are published under `intermediate/` when `save_intermediate_files = true`. Process logs and Nextflow reports are written under the timestamped `log-quantitate-ProteomicTMT-*` directory. Three NFTest integration cases are defined in [nftest.yml](nftest.yml); fixture setup is described in [test/README.md](test/README.md).

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
