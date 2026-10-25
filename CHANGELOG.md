# Changelog

## Unreleased (2026-10-24)

- Select mzML or premerged consensusXML input with `consensusXML_entrypoint`, using the matching source CSV and a separate `idXML.csv` joined by `plex_id`.
- Keep each plex keyed through extraction, normalization, ID mapping, and peptide quantification, and publish results in separate plex directories.
- Preserve the mzML CSV fraction order when parallel extraction feeds FileMerger.
- Convert the integration cases to entry-point-specific and idXML CSVs, with multi-plex coverage in the existing cases.
- Configure one `plex_type` per mzML run and derive each plex's reference channel from its channel descriptions.
- Supply one `channel_csv` keyed by `plex_id` so reporter descriptions are joined to each mzML plex without repeating channel paths in the mzML CSV.
- Mount `src` read-only for Python helper processes instead of staging helper scripts as data inputs.
- Require a labeled reference channel whenever OpenMS or physical-reference MAD normalization is selected.

## 1.0.0

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
