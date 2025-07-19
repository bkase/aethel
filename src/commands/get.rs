use crate::cli::OutputFormat;
use crate::config::load_config;
use crate::error::{AethelError, Result};
use crate::index::{create_pool, get_artifact_path};
use crate::store::{get_vault_path, read_artifact};
use uuid::Uuid;

pub async fn execute(uuid_str: &str, format: &OutputFormat) -> Result<()> {
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

    // Read artifact
    let artifact = read_artifact(&vault_path, &file_path)?;

    // Output based on format
    match format {
        OutputFormat::Markdown => {
            println!("---");
            println!("{}", serde_yaml::to_string(&artifact.frontmatter)?);
            println!("---");
            println!("{}", artifact.content);
        }
        OutputFormat::Json => {
            let json = serde_json::json!({
                "frontmatter": artifact.frontmatter,
                "content": artifact.content,
                "path": file_path,
            });
            println!("{}", serde_json::to_string_pretty(&json)?);
        }
    }

    Ok(())
}
