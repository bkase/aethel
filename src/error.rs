use thiserror::Error;

#[derive(Debug, Error)]
pub enum AethelError {
    #[error("Configuration not found. Please run 'aethel init <path>'.")]
    ConfigNotFound,

    #[error("A circular dependency was detected in your schema extensions involving '{0}'.")]
    CircularSchemaDependency(String),

    #[error("Database error: {0}")]
    Sqlx(#[from] sqlx::Error),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("YAML error: {0}")]
    Yaml(#[from] serde_yaml::Error),

    #[error("Git error: {0}")]
    Git(#[from] git2::Error),

    #[error("Vault not found at path: {0}")]
    VaultNotFound(String),

    #[error("Plugin not found: {0}")]
    PluginNotFound(String),

    #[error("Schema not found: {0}")]
    SchemaNotFound(String),

    #[error("Invalid artifact type: {0}")]
    #[allow(dead_code)]
    InvalidArtifactType(String),

    #[error("Artifact not found with UUID: {0}")]
    ArtifactNotFound(String),

    #[error("Invalid UUID: {0}")]
    InvalidUuid(String),

    #[error("Validation error: {0}")]
    ValidationError(String),

    #[error("Binary serialization error: {0}")]
    Bincode(#[from] Box<bincode::ErrorKind>),

    #[error("{0}")]
    Other(String),
}

pub type Result<T> = std::result::Result<T, AethelError>;
