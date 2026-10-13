# quantitate-ProteomicTMT

Quantifies peptides from one isobaric labeled plex using OpenMS and MSPTools. The pipeline accepts a CSV of mzML fractions plus an idXML, or a premerged consensusXML plus an idXML. All mzML rows must belong to the same plex. Reporter channels are samples within that plex; the pipeline does not use LFQ sample or fraction grouping.

## Run

Copy [config/template.config](config/template.config), fill in absolute paths, and run `nextflow run . -c your.config -profile docker`. Use `-profile apptainer` or `-profile singularity` on a cluster. For mzML input, use the one-column [input/input.csv](input/input.csv) template and a channel CSV with `channel,description` columns. Omit `input_csv` and set `merged_consensusXML` to begin after extraction and merging. Set exactly one entry point.

The default OpenMS and pyOpenMS images use version 3.5.0; MSPTools uses the `dev` image. Set `resource_allocation_profile_tag` to a key in `config/resources.json`; process allocations use the shared resource handler. Use `base_resource_update` for overrides. `save_intermediate_files` copies process intermediates into the output tree.

## Workflow

mzML input: `FileFilter -sort` → `IsobaricAnalyzer` → `FileMerger -append_method append_rows`. The premerged entry point starts at the supplied consensusXML. With `enable_tmt_normalization = true` (default), `tmt_normalization_method = 'mad'` runs MSPtools MAD normalization before `IDMapper`; optional NaN-handle removal is disabled by default. Choose `'openms'` to enable median-ratio normalization in IsobaricAnalyzer and skip MSPtools normalization; this choice requires mzML input. Set `enable_tmt_normalization = false` to skip normalization. For mzML input, consensusXML column filenames are set to `plex_name` after merging. Before `IDMapper`, the pipeline writes a temporary idXML copy with run names matching the consensusXML column filename. It checks that merged source files do not reuse native scan IDs; files with overlapping scan IDs must be mapped separately before merging. `IDConflictResolver` and `ProteinQuantifier` follow. `protein_quantifier_best_charge_and_fraction` defaults to `true`, reporting peptide abundances separately by fraction and charge state; set it to `false` to omit that flag and let OpenMS aggregate charge states. MSPtools reads the plex-specific abundance column headers written by OpenMS 3.5 and converts all-zero plex values to missing values. With `protein_quantifier_best_charge_and_fraction = true`, it also uses the consensusXML to mark unquantified reporter channels as missing; with `false`, the charge-aggregated peptide CSV cannot support that channel-level lookup. `remove_mapped_consensus = true` also writes a consensusXML of unmapped features.

Important parameters: `plex_name`, `tmt_normalization_method`, `enable_tmt_normalization`, `mad_normalizer_quasi_intensity`, `filter_na_consensus_handles`, `isobaric_analyzer_type` (for example `tmt10plex`), `reference_channel`, `correction_matrix`, `channel_description`, `virtual_reference`, `virtual_reference_method`, `protein_quantifier_best_charge_and_fraction`, and `remove_mapped_consensus`. The correction matrix is passed directly to OpenMS as a space-separated set of reporter rows. See [docs/params.rst](docs/params.rst) for the command parameter list. Channel CSV labels must match the chosen plex type. `channel_description` applies only to mzML extraction; a premerged consensusXML must already contain channel descriptions in its column headers. For MAD normalization, `mad_normalizer_quasi_intensity = true` (default) writes reference-scaled quasi-intensities rather than normalized log2 ratios; set it to `false` for the ratio output. `filter_na_consensus_handles = false` retains missing reporter handles as NaN, preserving channel positions in the D’Angelo integration test. MSPtools release 1.0.1 predates these MAD fixes; select an image containing `--quasi-intensity` when using MAD normalization.

## Outputs

Results are written under `<output_dir>/quantitate-ProteomicTMT-<version>/<plex_name>/OpenMS-<version>/output`. The directory contains the merged `FileMerger.consensusXML` when extraction runs, the mapped `IDMapper.consensusXML`, the resolved `IDConflictResolver.consensusXML`, the final peptide CSV (`*_ProteinQuantifier_peptide.csv` without normalization or `*_fixZeroPlex.csv` with normalization), and optionally `*_unmapped.consensusXML`. Logs, trace, timeline, report, and parameter JSON are written in a timestamped sibling `log-*` directory.

## Tests

See [test/README.md](test/README.md) for the four NFTest integration cases and external fixture environment variables. Integration runs require cluster fixture files and container access.

## License

GNU GPL v2 or later; see [LICENSE](LICENSE).
