use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ArtifactFrontmatter {
    pub uuid: Uuid,
    #[serde(rename = "type")]
    pub artifact_type: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    #[serde(default)]
    pub tags: Vec<String>,
    pub schema_version: String,
    #[serde(flatten)]
    pub extra: HashMap<String, serde_yaml::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Artifact {
    pub frontmatter: ArtifactFrontmatter,
    pub content: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SchemaField {
    pub name: String,
    #[serde(rename = "type")]
    pub field_type: String,
    pub required: bool,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub default: Option<serde_yaml::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Schema {
    pub name: String,
    pub extends: Option<String>,
    pub description: Option<String>,
    pub fields: Vec<SchemaField>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Plugin {
    pub id: String,
    pub name: String,
    pub description: String,
    pub version: String,
    pub author: Option<String>,
    pub schemas: HashMap<String, Schema>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Registry {
    pub plugins: HashMap<String, Plugin>,
    pub resolved_schemas: HashMap<String, Vec<SchemaField>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub vault_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VaultMetadata {
    pub version: String,
    pub created_at: DateTime<Utc>,
}
