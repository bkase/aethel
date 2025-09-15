use std::path::PathBuf;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum A4Error {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Vault not found: tried {attempts:?}")]
    VaultNotFound { attempts: Vec<String> },

    #[error("Invalid vault path: {path}")]
    InvalidVaultPath { path: PathBuf },

    #[error("Invalid anchor token: {token} - {reason}")]
    InvalidAnchorToken { token: String, reason: String },

    #[error("Git error: {0}")]
    Git(String),

    #[error("Path traversal attempt detected: {path}")]
    PathTraversal { path: PathBuf },

    #[error("Invalid UTF-8 in file: {path}")]
    InvalidUtf8 { path: PathBuf },

    #[error("Template not found: {path}")]
    TemplateNotFound { path: PathBuf },

    #[error("Git repository not initialized at {path}. Initialize with 'git init' and set remote, or use 'a4 sync --init' (future)")]
    GitRepoNotFound { path: PathBuf },

    #[error("Git divergence detected: local HEAD at {local_sha}, remote at {remote_sha}. Resolve divergence via manual rebase/merge")]
    GitDivergence {
        local_sha: String,
        remote_sha: String,
    },

    #[error("No remote configured for repository")]
    NoRemote,

    #[error("Failed to parse front matter: {0}")]
    FrontMatterParse(String),
}
