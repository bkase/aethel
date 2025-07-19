use crate::config::load_config;
use crate::error::{AethelError, Result};
use crate::index::{create_pool, get_artifact_path};
use crate::store::{get_vault_path, read_artifact, write_artifact};
use crate::utils::get_current_timestamp;
use uuid::Uuid;

pub async fn execute(uuid_str: &str, content: &str) -> Result<()> {
    let config = load_config()?;
    let vault_path = get_vault_path(&config.vault_path)?;

    // Parse UUID
    let uuid =
        Uuid::parse_str(uuid_str).map_err(|_| AethelError::InvalidUuid(uuid_str.to_string()))?;

    // Get artifact path from index
    let pool = create_pool(&vault_path).await?;
    let file_path = get_artifact_path(&pool, &uuid)
        .await?
        .ok_or_else(|| AethelError::ArtifactNotFound(uuid_str.to_string()))?;

    // Read existing artifact
    let mut artifact = read_artifact(&vault_path, &file_path)?;

    // Append content
    if !artifact.content.is_empty() {
        artifact.content.push_str("\n\n");
    }
    artifact.content.push_str(content);

    // Update timestamp
    artifact.frontmatter.updated_at = get_current_timestamp();

    // Write back
    write_artifact(&vault_path, &file_path, &artifact)?;
    
    // Silent on success for better scripting compatibility
    Ok(())
}
