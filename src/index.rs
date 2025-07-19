use crate::error::Result;
use sqlx::{Pool, Sqlite, sqlite::SqlitePoolOptions};
use std::path::Path;
use uuid::Uuid;

pub async fn create_pool(vault_path: &Path) -> Result<Pool<Sqlite>> {
    let aethel_dir = vault_path.join(".aethel");
    std::fs::create_dir_all(&aethel_dir)?;
    
    let db_path = aethel_dir.join("index.db");
    let db_url = format!("sqlite://{}?mode=rwc", db_path.display());
    
    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect(&db_url)
        .await?;
    
    Ok(pool)
}

pub async fn init_database(pool: &Pool<Sqlite>) -> Result<()> {
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS artifacts (
            uuid TEXT PRIMARY KEY NOT NULL,
            filepath TEXT NOT NULL
        );
        "#,
    )
    .execute(pool)
    .await?;
    
    Ok(())
}

pub async fn insert_artifact(pool: &Pool<Sqlite>, uuid: &Uuid, filepath: &str) -> Result<()> {
    sqlx::query(
        "INSERT INTO artifacts (uuid, filepath) VALUES (?, ?)"
    )
    .bind(uuid.to_string())
    .bind(filepath)
    .execute(pool)
    .await?;
    
    Ok(())
}

pub async fn get_artifact_path(pool: &Pool<Sqlite>, uuid: &Uuid) -> Result<Option<String>> {
    let result = sqlx::query_as::<_, (String,)>(
        "SELECT filepath FROM artifacts WHERE uuid = ?"
    )
    .bind(uuid.to_string())
    .fetch_optional(pool)
    .await?;
    
    Ok(result.map(|(path,)| path))
}

pub async fn delete_artifact(pool: &Pool<Sqlite>, uuid: &Uuid) -> Result<()> {
    sqlx::query(
        "DELETE FROM artifacts WHERE uuid = ?"
    )
    .bind(uuid.to_string())
    .execute(pool)
    .await?;
    
    Ok(())
}

pub async fn rebuild_index(pool: &Pool<Sqlite>, artifacts: Vec<(Uuid, String)>) -> Result<()> {
    sqlx::query("DELETE FROM artifacts")
        .execute(pool)
        .await?;
    
    for (uuid, filepath) in artifacts {
        insert_artifact(pool, &uuid, &filepath).await?;
    }
    
    Ok(())
}