use crate::config::save_config;
use crate::models::Config;
use crate::error::Result;
use crate::index::{create_pool, init_database};
use crate::store::ensure_vault_structure;
use crate::utils::init_git_repo;
use std::fs;
use std::path::Path;

pub async fn execute(path: &str) -> Result<()> {
    let vault_path = Path::new(path);
    
    // Create vault directory
    fs::create_dir_all(vault_path)?;
    
    // Create vault structure
    ensure_vault_structure(vault_path)?;
    
    // Initialize SQLite database
    let pool = create_pool(vault_path).await?;
    init_database(&pool).await?;
    
    // Create example core_note plugin
    create_example_plugin(vault_path)?;
    
    // Initialize Git repository
    init_git_repo(vault_path)?;
    
    // Save configuration
    let config = Config {
        vault_path: vault_path.canonicalize()?.to_string_lossy().to_string(),
    };
    save_config(&config)?;
    
    println!("Initialized new Aethel vault at: {}", path);
    println!("Configuration saved to: ~/.config/aethel/config.json");
    
    Ok(())
}

fn create_example_plugin(vault_path: &Path) -> Result<()> {
    let plugin_dir = vault_path.join("99_system/plugins/core_note");
    fs::create_dir_all(&plugin_dir)?;
    
    // Create plugin.aethel.md
    let plugin_content = r#"---
name: Core Note
version: 1.0
description: Basic note-taking plugin for Aethel
author: Aethel Team
---

# Core Note Plugin

This plugin provides basic note-taking functionality for your Aethel vault.

## Features

- Simple text notes with title and content
- Tag support for organization
- Timestamp tracking

## Usage

Create a new note:
```bash
aethel new --type note --title "My First Note"
```
"#;
    
    fs::write(plugin_dir.join("plugin.aethel.md"), plugin_content)?;
    
    // Create schemas directory
    let schemas_dir = plugin_dir.join("schemas");
    fs::create_dir_all(&schemas_dir)?;
    
    // Create note schema
    let note_schema = r#"---
name: note
description: A simple text note
fields:
  - name: title
    type: string
    required: true
    description: The title of the note
---

# Note Schema

This schema defines the structure for basic notes in your Aethel vault.
"#;
    
    fs::write(schemas_dir.join("note.aethel.md"), note_schema)?;
    
    Ok(())
}