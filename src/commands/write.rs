use crate::config::load_config;
use crate::error::{AethelError, Result};
use crate::index::{create_pool, get_artifact_path, insert_artifact};
use crate::models::{Artifact, ArtifactFrontmatter};
use crate::registry::load_registry;
use crate::store::{get_plugin_artifact_dir, get_vault_path, read_artifact, write_artifact};
use crate::utils::{generate_filename, get_current_timestamp};
use std::collections::HashMap;
use std::path::Path;
use uuid::Uuid;

pub async fn execute(
    uuid: Option<&str>,
    r#type: Option<&str>,
    content: &str,
    title: Option<&str>,
    fields: &[(String, String)],
) -> Result<()> {
    let config = load_config()?;
    let vault_path = get_vault_path(&config.vault_path)?;

    match uuid {
        Some(uuid_str) => {
            // Append mode: UUID provided
            append_to_artifact(&vault_path, uuid_str, content).await
        }
        None => {
            // Create mode: No UUID provided
            create_new_artifact(&vault_path, r#type, content, title, fields).await
        }
    }
}

async fn append_to_artifact(
    vault_path: &Path,
    uuid_str: &str,
    content: &str,
) -> Result<()> {
    // Validate UUID format
    let uuid = Uuid::parse_str(uuid_str).map_err(|_| AethelError::InvalidUuid(uuid_str.to_string()))?;

    // Get artifact file path from index
    let pool = create_pool(vault_path).await?;
    let file_path = get_artifact_path(&pool, &uuid)
        .await?
        .ok_or_else(|| AethelError::ArtifactNotFound(uuid_str.to_string()))?;

    // Read existing artifact
    let mut artifact = read_artifact(vault_path, &file_path)?;
    
    // Append content with proper spacing
    if !artifact.content.is_empty() {
        artifact.content.push_str("\n\n");
    }
    artifact.content.push_str(content);
    
    // Update timestamp
    artifact.frontmatter.updated_at = get_current_timestamp();
    
    // Write back
    write_artifact(vault_path, &file_path, &artifact)?;
    
    Ok(())
}

async fn create_new_artifact(
    vault_path: &Path,
    r#type: Option<&str>,
    content: &str,
    title: Option<&str>,
    fields: &[(String, String)],
) -> Result<()> {
    // Type is required for new artifacts
    let artifact_type = r#type.ok_or_else(|| {
        AethelError::Io(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "Type is required when creating new artifacts",
        ))
    })?;

    // Load registry
    let registry = load_registry(vault_path).await?;
    
    // Parse type and get plugin
    let (plugin_id, _schema_name) = artifact_type
        .split_once('/')
        .unwrap_or(("core_note", artifact_type));
    
    // Verify plugin exists
    if !registry.plugins.contains_key(plugin_id) {
        return Err(AethelError::PluginNotFound(plugin_id.to_string()));
    }
    
    // Create artifact
    let timestamp = get_current_timestamp();
    let uuid = Uuid::new_v4();
    
    let mut extra = HashMap::new();
    if let Some(title) = title {
        extra.insert(
            "title".to_string(),
            serde_yaml::Value::String(title.to_string()),
        );
    }
    for (key, value) in fields {
        extra.insert(key.clone(), serde_yaml::Value::String(value.clone()));
    }
    
    let frontmatter = ArtifactFrontmatter {
        uuid,
        artifact_type: artifact_type.to_string(),
        created_at: timestamp,
        updated_at: timestamp,
        tags: vec![],
        schema_version: "1.0".to_string(),
        extra,
    };
    
    let artifact = Artifact {
        frontmatter,
        content: content.to_string(),
    };
    
    // Determine file path
    let filename = format!("{}.md", generate_filename(&timestamp));
    let artifact_dir = get_plugin_artifact_dir(vault_path, plugin_id, &timestamp);
    let relative_path = artifact_dir
        .join(&filename)
        .strip_prefix(vault_path)
        .unwrap_or(Path::new(&filename))
        .to_string_lossy()
        .to_string();
    
    // Write artifact
    write_artifact(vault_path, &relative_path, &artifact)?;
    
    // Update index
    let pool = create_pool(vault_path).await?;
    insert_artifact(&pool, &uuid, &relative_path).await?;
    
    // Print UUID for scripting
    println!("{uuid}");
    
    Ok(())
}