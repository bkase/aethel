use crate::config::load_config;
use crate::error::Result;
use crate::index::{create_pool, rebuild_index};
use crate::registry::load_registry;
use crate::store::{get_vault_path, parse_artifact, scan_vault_artifacts, write_artifact};
use crate::utils::get_current_timestamp;
use std::fs;
use walkdir::WalkDir;

pub async fn execute(fix: bool, rebuild_index_flag: bool) -> Result<()> {
    let config = load_config()?;
    let vault_path = get_vault_path(&config.vault_path)?;

    println!("Running vault diagnostics...");

    // Check vault structure
    let required_dirs = [
        "00_inbox",
        "10_sources",
        "20_artifacts",
        "30_knowledge",
        "99_system",
        ".aethel",
    ];

    for dir in &required_dirs {
        let dir_path = vault_path.join(dir);
        if !dir_path.exists() {
            println!("❌ Missing directory: {dir}");
            if fix {
                fs::create_dir_all(&dir_path)?;
                println!("  ✅ Created: {dir}");
            }
        } else {
            println!("✅ Directory exists: {dir}");
        }
    }

    // Check .gitignore
    let gitignore_path = vault_path.join(".gitignore");
    if !gitignore_path.exists() {
        println!("❌ Missing .gitignore file");
        if fix {
            fs::write(&gitignore_path, ".aethel/\n")?;
            println!("  ✅ Created .gitignore");
        }
    }

    // Load registry
    let registry = load_registry(&vault_path).await?;
    println!("✅ Loaded {} plugins", registry.plugins.len());

    // Validate artifacts
    let artifacts_dir = vault_path.join("20_artifacts");
    let mut issues = 0;
    let mut fixed = 0;

    if artifacts_dir.exists() {
        for entry in WalkDir::new(&artifacts_dir)
            .into_iter()
            .filter_map(|e| e.ok())
        {
            if entry.file_type().is_file() {
                if let Some(ext) = entry.path().extension() {
                    if ext == "md" {
                        let path = entry.path();
                        let relative_path = path
                            .strip_prefix(&vault_path)
                            .unwrap_or(path)
                            .to_string_lossy()
                            .to_string();

                        match fs::read_to_string(path) {
                            Ok(content) => {
                                match parse_artifact(&content) {
                                    Ok(mut artifact) => {
                                        // Check if updatedAt needs updating
                                        let needs_update = artifact.frontmatter.updated_at
                                            < artifact.frontmatter.created_at;

                                        if needs_update {
                                            println!("⚠️  Invalid timestamp in: {relative_path}");
                                            issues += 1;

                                            if fix {
                                                artifact.frontmatter.updated_at =
                                                    get_current_timestamp();
                                                write_artifact(
                                                    &vault_path,
                                                    &relative_path,
                                                    &artifact,
                                                )?;
                                                println!("  ✅ Fixed timestamp");
                                                fixed += 1;
                                            }
                                        }
                                    }
                                    Err(e) => {
                                        println!(
                                            "❌ Invalid artifact format in {relative_path}: {e}"
                                        );
                                        issues += 1;
                                    }
                                }
                            }
                            Err(e) => {
                                println!("❌ Failed to read {relative_path}: {e}");
                                issues += 1;
                            }
                        }
                    }
                }
            }
        }
    }

    // Rebuild index if requested
    if rebuild_index_flag {
        println!("\nRebuilding artifact index...");
        let artifacts = scan_vault_artifacts(&vault_path)?;
        let pool = create_pool(&vault_path).await?;
        rebuild_index(&pool, artifacts).await?;
        println!("✅ Index rebuilt successfully");
    }

    // Summary
    println!("\n=== Summary ===");
    println!("Total issues found: {issues}");
    if fix {
        println!("Issues fixed: {fixed}");
    }

    if issues > 0 && !fix {
        println!("\nRun with --fix to automatically resolve issues");
    }

    Ok(())
}
