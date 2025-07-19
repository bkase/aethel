use crate::error::{AethelError, Result};
use crate::models::Config;
use std::fs;
use std::path::{Path, PathBuf};

pub fn get_config_dir() -> Result<PathBuf> {
    let config_dir = xdg::BaseDirectories::with_prefix("aethel")
        .map_err(|e| AethelError::Other(format!("Failed to get XDG directories: {e}")))?
        .get_config_home();
    Ok(config_dir)
}

pub fn get_config_path() -> Result<PathBuf> {
    Ok(get_config_dir()?.join("config.json"))
}

pub fn load_config() -> Result<Config> {
    let config_path = get_config_path()?;

    if !config_path.exists() {
        return Err(AethelError::ConfigNotFound);
    }

    let content = fs::read_to_string(&config_path)?;
    let config: Config = serde_json::from_str(&content)?;
    Ok(config)
}

pub fn save_config(config: &Config) -> Result<()> {
    let config_dir = get_config_dir()?;
    fs::create_dir_all(&config_dir)?;

    let config_path = get_config_path()?;
    let content = serde_json::to_string_pretty(config)?;
    fs::write(&config_path, content)?;
    Ok(())
}

#[allow(dead_code)]
pub fn ensure_vault_exists(path: &Path) -> Result<()> {
    if !path.exists() || !path.is_dir() {
        return Err(AethelError::VaultNotFound(path.display().to_string()));
    }
    Ok(())
}
