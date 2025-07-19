# Aethel Todo List

### 1. Update Artifact Storage Path Format

- [ ] Modify artifact path generation in `src/plugin/registry.rs` to support:
  - Pattern: `20_artifacts/{plugin_id}/YYYY/MM/DDTHH-MM-SSZ_{uuid}.md`
  - Separate year/month directories for better organization
  - ISO timestamp prefix for chronological sorting

