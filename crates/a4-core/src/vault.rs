use crate::date::UtcDay;
use crate::error::A4Error;
use fs_err as fs;
use std::env;
use std::path::{Path, PathBuf};

pub struct Vault {
    root: PathBuf,
}

#[derive(Debug, Clone)]
pub enum VaultRoot {
    FromCli(PathBuf),
    FromEnv(PathBuf),
    FromMarker(PathBuf),
    Default(PathBuf),
}

#[derive(Default)]
pub struct VaultOpts {
    pub ensure_exists: bool,
}

impl Vault {
    pub fn open<P: AsRef<Path>>(path: P, opts: VaultOpts) -> Result<Self, A4Error> {
        let path = path.as_ref();

        if !path.exists() && opts.ensure_exists {
            fs::create_dir_all(path)?;
        }

        if !path.exists() {
            return Err(A4Error::InvalidVaultPath {
                path: path.to_path_buf(),
            });
        }

        let root = fs::canonicalize(path)?;
        Ok(Vault { root })
    }

    pub fn resolve_default() -> Result<(Self, VaultRoot), A4Error> {
        let mut attempts = Vec::new();

        if let Ok(vault_env) = env::var("A4_VAULT_DIR") {
            let path = PathBuf::from(&vault_env);
            attempts.push(format!("A4_VAULT_DIR={vault_env}"));
            if path.exists() {
                let vault = Self::open(&path, VaultOpts::default())?;
                return Ok((vault, VaultRoot::FromEnv(path)));
            }
        }

        let cwd = env::current_dir()?;
        let mut current = cwd.as_path();
        loop {
            let marker = current.join(".a4");
            if marker.exists() && marker.is_dir() {
                attempts.push(format!(".a4 marker at {}", current.display()));
                let vault = Self::open(current, VaultOpts::default())?;
                return Ok((vault, VaultRoot::FromMarker(current.to_path_buf())));
            }

            match current.parent() {
                Some(parent) => current = parent,
                None => break,
            }
        }

        let home = env::var("HOME").map_err(|_| A4Error::VaultNotFound {
            attempts: attempts.clone(),
        })?;
        let default_path = PathBuf::from(home).join("Documents").join("a4-core");
        attempts.push(format!(
            "$HOME/Documents/a4-core ({})",
            default_path.display()
        ));

        if default_path.exists() {
            let vault = Self::open(&default_path, VaultOpts::default())?;
            Ok((vault, VaultRoot::Default(default_path)))
        } else {
            let vault = Self::open(
                &default_path,
                VaultOpts {
                    ensure_exists: true,
                },
            )?;
            Ok((vault, VaultRoot::Default(default_path)))
        }
    }

    pub fn resolve_with_override(
        override_path: Option<PathBuf>,
    ) -> Result<(Self, VaultRoot), A4Error> {
        if let Some(path) = override_path {
            let vault = Self::open(&path, VaultOpts::default())?;
            Ok((vault, VaultRoot::FromCli(path)))
        } else {
            Self::resolve_default()
        }
    }

    pub fn capture_day_path(&self, utc_day: UtcDay) -> PathBuf {
        let year_dir = format!("{:04}", utc_day.year);
        let month_dir = format!("{:04}-{:02}", utc_day.year, utc_day.month);
        let filename = format!(
            "{:04}-{:02}-{:02}.md",
            utc_day.year, utc_day.month, utc_day.day
        );

        self.root
            .join("capture")
            .join(year_dir)
            .join(month_dir)
            .join(filename)
    }

    pub fn ensure_parents(&self, path: &Path) -> Result<(), A4Error> {
        // For absolute paths, just use them as-is
        // For relative paths, join with vault root
        let check_path = if path.is_absolute() {
            path.to_path_buf()
        } else {
            self.root.join(path)
        };

        // Only check path traversal for relative paths
        if !path.is_absolute() && !check_path.starts_with(&self.root) {
            return Err(A4Error::PathTraversal { path: check_path });
        }

        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }

        Ok(())
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    pub fn template_path(&self) -> PathBuf {
        self.root
            .join("routines")
            .join("templates")
            .join("daily.md")
    }
}
