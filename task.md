# Update Artifact Storage Path Format

**Status:** InProgress
**Agent PID:** 9319

## Original Todo

- [ ] Modify artifact path generation in `src/plugin/registry.rs` to support:
  - Pattern: `20_artifacts/{plugin_id}/YYYY/MM/DDTHH-MM-SSZ_{uuid}.md`
  - Separate year/month directories for better organization
  - ISO timestamp prefix for chronological sorting

## Description

We're updating the artifact storage path format in Aethel to improve organization and sorting. The new format will store artifacts in year/month subdirectories with ISO-compliant timestamps. This change will make browsing artifacts easier by organizing them chronologically in directories.

Current format: `20_artifacts/{plugin_id}/2025-07-19-14-30-45.md`
New format: `20_artifacts/{plugin_id}/2025/07/19T14-30-45Z.md`

## Implementation Plan

- [x] Update `generate_filename()` in `src/utils.rs` to use ISO format `DDTHH-MM-SSZ` instead of `YYYY-MM-DD-HH-MM-SS`
- [x] Update `get_plugin_artifact_dir()` in `src/store.rs` to return `vault_path/20_artifacts/{plugin_id}/YYYY/MM` with year/month subdirectories
- [x] Update `new.rs` command to ensure year/month directories are created before writing artifact
- [x] Update `scan_vault_artifacts()` in `src/store.rs` to recursively scan the new nested directory structure
- [x] Update documentation in `docs/` to reflect the new artifact path format
- [x] Update `CLAUDE.md` to document the new path format for future development
- [ ] Run `cargo clippy` and `cargo fmt` to ensure code quality
- [ ] Test creating a new artifact to verify the new path format works correctly
- [ ] Test `aethel doctor` command to ensure it still validates the vault structure

## Notes

The artifact path generation happens in src/commands/new.rs, not in src/plugin/registry.rs as originally stated in the todo.