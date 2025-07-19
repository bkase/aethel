use crate::config::load_config;
use crate::error::{AethelError, Result};
use crate::index::{create_pool, insert_artifact};
use crate::models::{Artifact, ArtifactFrontmatter};
use crate::registry::load_registry;
use crate::store::{get_plugin_artifact_dir, get_vault_path, write_artifact};
use crate::utils::{generate_filename, get_current_timestamp};
use std::collections::HashMap;
use std::path::Path;
use uuid::Uuid;

pub async fn execute(
    artifact_type: &str,
    title: Option<&str>,
    fields: &[(String, String)],
    body: Option<&str>,
) -> Result<()> {
    let config = load_config()?;
    let vault_path = get_vault_path(&config.vault_path)?;

    // Load registry
    let registry = load_registry(&vault_path).await?;

    // Find the plugin and schema for this type
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
        content: body.unwrap_or("").to_string(),
    };

    // Determine file path
    let filename = format!("{}.md", generate_filename(&timestamp));
    let artifact_dir = get_plugin_artifact_dir(&vault_path, plugin_id);
    let relative_path = artifact_dir
        .join(&filename)
        .strip_prefix(&vault_path)
        .unwrap_or(Path::new(&filename))
        .to_string_lossy()
        .to_string();

    // Write artifact
    write_artifact(&vault_path, &relative_path, &artifact)?;

    // Update index
    let pool = create_pool(&vault_path).await?;
    insert_artifact(&pool, &uuid, &relative_path).await?;

    // Output only UUID for scripting compatibility
    println!("{uuid}");

    Ok(())
}
