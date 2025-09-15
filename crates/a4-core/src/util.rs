use crate::error::A4Error;
use std::path::{Path, PathBuf};

pub fn safe_join(base: &Path, path: &Path) -> Result<PathBuf, A4Error> {
    let joined = base.join(path);
    let canonical = if joined.exists() {
        std::fs::canonicalize(&joined)?
    } else {
        joined.clone()
    };

    if !canonical.starts_with(base) {
        return Err(A4Error::PathTraversal { path: canonical });
    }

    Ok(canonical)
}

pub fn ensure_trailing_newline(s: &str) -> String {
    if s.ends_with('\n') {
        s.to_string()
    } else {
        format!("{s}\n")
    }
}
