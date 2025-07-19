use crate::error::{AethelError, Result};
use crate::models::{Artifact, ArtifactFrontmatter};
use std::fs;
use std::path::{Path, PathBuf};
use uuid::Uuid;
use walkdir::WalkDir;

pub fn get_vault_path(config_vault_path: &str) -> Result<PathBuf> {
    let path = PathBuf::from(config_vault_path);
    if !path.exists() || !path.is_dir() {
        return Err(AethelError::VaultNotFound(config_vault_path.to_string()));
    }
    Ok(path)
}

pub fn read_artifact(vault_path: &Path, file_path: &str) -> Result<Artifact> {
    let full_path = vault_path.join(file_path);
    if !full_path.exists() {
        return Err(AethelError::ArtifactNotFound(file_path.to_string()));
    }

    let content = fs::read_to_string(&full_path)?;
    parse_artifact(&content)
}

pub fn write_artifact(vault_path: &Path, file_path: &str, artifact: &Artifact) -> Result<()> {
    let full_path = vault_path.join(file_path);

    // Ensure parent directory exists
    if let Some(parent) = full_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let content = serialize_artifact(artifact)?;
    fs::write(&full_path, content)?;
    Ok(())
}

pub fn parse_artifact(content: &str) -> Result<Artifact> {
    let parts: Vec<&str> = content.splitn(3, "---").collect();
    if parts.len() < 3 {
        return Err(AethelError::ValidationError(
            "Invalid artifact format: missing frontmatter".to_string(),
        ));
    }

    let frontmatter: ArtifactFrontmatter = serde_yaml::from_str(parts[1])?;
    let body = parts[2].trim().to_string();

    Ok(Artifact {
        frontmatter,
        content: body,
    })
}

pub fn serialize_artifact(artifact: &Artifact) -> Result<String> {
    let frontmatter = serde_yaml::to_string(&artifact.frontmatter)?;
    Ok(format!("---\n{}---\n{}", frontmatter, artifact.content))
}

pub fn scan_vault_artifacts(vault_path: &Path) -> Result<Vec<(Uuid, String)>> {
    let mut artifacts = Vec::new();
    let artifacts_dir = vault_path.join("20_artifacts");

    if artifacts_dir.exists() {
        for entry in WalkDir::new(&artifacts_dir)
            .into_iter()
            .filter_map(|e| e.ok())
        {
            if entry.file_type().is_file() {
                if let Some(ext) = entry.path().extension() {
                    if ext == "md" {
                        if let Ok(content) = fs::read_to_string(entry.path()) {
                            if let Ok(artifact) = parse_artifact(&content) {
                                let relative_path = entry
                                    .path()
                                    .strip_prefix(vault_path)
                                    .unwrap_or(entry.path())
                                    .to_string_lossy()
                                    .to_string();
                                artifacts.push((artifact.frontmatter.uuid, relative_path));
                            }
                        }
                    }
                }
            }
        }
    }

    Ok(artifacts)
}

pub fn get_plugin_artifact_dir(
    vault_path: &Path,
    plugin_id: &str,
    timestamp: &chrono::DateTime<chrono::Utc>,
) -> PathBuf {
    vault_path
        .join("20_artifacts")
        .join(plugin_id)
        .join(timestamp.format("%Y").to_string())
        .join(timestamp.format("%m").to_string())
}

#[allow(dead_code)]
pub fn get_plugin_source_dir(vault_path: &Path, plugin_id: &str) -> PathBuf {
    vault_path.join("10_sources").join(plugin_id)
}

pub fn ensure_vault_structure(vault_path: &Path) -> Result<()> {
    let dirs = [
        "00_inbox",
        "10_sources",
        "20_artifacts",
        "30_knowledge",
        "99_system",
        "99_system/plugins",
        ".aethel",
    ];

    for dir in &dirs {
        fs::create_dir_all(vault_path.join(dir))?;
    }

    // Create .gitignore
    let gitignore_content = ".aethel/\n";
    fs::write(vault_path.join(".gitignore"), gitignore_content)?;

    Ok(())
}
