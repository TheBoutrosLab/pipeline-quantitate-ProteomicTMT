# Changelog

## [Unreleased]

## [2.1.0] - 2026-11-11

### Changed

- Upgrade OpenMS tool commands to 3.6.0 and replace ProteinQuantifier's removed `best_charge_and_fraction` flag with `best_charge`, retaining detailed peptide output.
- Keep assay-level fraction aggregation at `sum` and remove the OpenMS 3.5 peptide-column repair step now that OpenMS 3.6 writes full-width detailed rows.
- Remove the ratio flags deleted from ProteinQuantifier 3.6 and update the peptide cleanup, tests, and documentation.

## [2.0.0] - 2026-11-08

### Added

- Add a schematic showing the shared TMT inputs and outputs, separate scan and feature paths, and common peptide quantification steps.
- Separate `scan_based` and `feature_based` workflows, selected with `tmt_workflow`; add an optional MS1 feature-based TMT workflow with per-run idXML selection, FFId feature detection, fraction-matched RT alignment, reporter-scan assignment, MS1-scale channel-area estimation, and cross-plex feature linking.
- Add a feature-based NFTest case using the D’Angelo fixture subset.
- Preserve each plex's MS1 area and per-channel reporter sums across feature linking in the final consensusXML metadata and a linked feature table.
- Produce one conflict-resolved dataset consensusXML and peptide CSV from either workflow; merge scan-based plexes as columns and feature-based fractions as rows.
- Combine linked feature/channel TSVs across all fractions and plexes.

### Changed

- Group tool settings under nested program-name namespaces and build command options from set values without module-level parameter maps.
- Link feature-based plexes using matching peptide identifications and configurable RT and 10-ppm m/z tolerances.
- Keep OpenMS reporter normalization off for feature-based TMT and support MSPtools MAD normalization on the merged linked map.
- Use the required `dataset_id` for final filenames and remove the hard-coded cohort grouping key.
- Pass files directly through final conflict resolution, peptide quantification, and CSV cleanup; keep peptide output as CSV.
- Publish pre-resolution dataset consensusXMLs for inspection; keep plex-specific and fraction-specific maps and feature allocation diagnostics under optional intermediate output.
- Update the default MSPtools image to v1.1.1 and normalize merged scan or linked maps before peptide quantification.
- Expose the MSPtools 1.1.1 virtual-reference minimum channel count, defaulting to one valid channel per feature and plex.
- Skip all-zero-plex cleanup for MAD log2 ratios, where zero means equality to the reference.
- Repair OpenMS 3.5 detailed peptide CSV rows that omit abundance fields for absent plexes, using the resolved consensusXML to place values before MSPtools cleanup.
- Make feature-based bridge scaling optional; compute factors from all valid reference areas per plex, without requiring shared features, and retain raw estimated areas alongside normalized areas and plex factors in the linked table. The D’Angelo feature-based test exercises median virtual-reference bridge scaling.

## [1.1.0] - 2026-10-24

### Changed

- Select mzML or premerged consensusXML input with `consensusXML_entrypoint`, using the matching source CSV and a separate `idXML.csv` joined by `plex_id`.
- Keep each plex keyed through extraction, normalization, ID mapping, and peptide quantification, and publish results in separate plex directories.
- Preserve the mzML CSV fraction order when parallel extraction feeds FileMerger.
- Convert the integration cases to entry-point-specific and idXML CSVs, with multi-plex coverage in the existing cases.
- Configure one `plex_type` per mzML run and derive each plex's reference channel from its channel descriptions.
- Supply one `channel_csv` keyed by `plex_id` so reporter descriptions are joined to each mzML plex without repeating channel paths in the mzML CSV.
- Mount `src` read-only for Python helper processes instead of staging helper scripts as data inputs.
- Require a labeled reference channel whenever OpenMS or physical-reference MAD normalization is selected.

## [1.0.0]

### Changed

- Implemented the isobaric quantification workflow with mzML and premerged consensusXML entry points, optional MAD normalization, ID mapping, conflict resolution, and peptide quantification.
- Added shared schema, resource allocation, container profiles, and NFTest fixture configuration.
- Published the mapped consensusXML result and staged Python scripts for portable container execution.
- Made `ProteinQuantifier -best_charge_and_fraction` configurable, enabled by default. The zero-plex cleanup omits its charge-specific consensusXML lookup when the flag is disabled.
- Removed the obsolete CSV reheader step; OpenMS 3.5 supplies sample-specific abundance headers.
- Omitted unset optional entry-point paths from defaults so shared schema validation accepts either workflow.
- Aligned a temporary idXML copy to the merged TMT consensusXML filename for scan-based ID mapping, with a check for duplicate scan IDs across source runs.
- Read OpenMS 3.5 abundance headers directly through MSPtools during zero-plex cleanup.
- Added a MAD or OpenMS normalization choice and selected MAD with a physical reference channel for the D’Angelo integration test. MSPtools 1.0.2 supplies the required MAD fixes.
- Made post-MAD NaN-handle removal configurable and disabled it by default. Retaining NaN handles preserves reporter-channel positions in ProteinQuantifier output.
- Updated the virtual-reference integration case to use the D’Angelo fixtures and MAD median virtual-reference settings; it passed on the cluster with 888 aligned peptide rows.
- Enabled MSPtools MADNormalizer quasi-intensity output by default, with a parameter to retain normalized log2 ratios when needed. Both MAD integration cases passed with 888 aligned peptide rows each.
- Renamed the required TMT plex identifier from `sample_name` to `plex_name` across configuration, output naming, and integration fixtures.
- Removed the unused channel CSV from the premerged-consensusXML test and fixed its entry-point configuration. Updated the unmapped-feature script for pyOpenMS 3.5's typed peptide-identification list.

[1.0.0]: https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicTMT/releases/tag/v1.0.0
[1.1.0]: https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicTMT/compare/v1.0.0...v1.1.0
[2.0.0]: https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicTMT/compare/v1.1.0...v2.0.0
[2.1.0]: https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicTMT/compare/v2.0.0...v2.1.0
[unreleased]: https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicTMT/compare/v2.1.0...HEAD
