use crate::error::{AethelError, Result};
use crate::models::{Plugin, Registry, Schema, SchemaField};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::Path;
use std::time::SystemTime;
use walkdir::WalkDir;

pub async fn load_registry(vault_path: &Path) -> Result<Registry> {
    let cache_path = vault_path.join(".aethel/registry.cache");
    let plugins_dir = vault_path.join("99_system/plugins");
    
    // Check if we can use the cache
    if cache_path.exists() && plugins_dir.exists() {
        let cache_mtime = fs::metadata(&cache_path)?.modified()?;
        let plugins_mtime = get_latest_mtime(&plugins_dir)?;
        
        if cache_mtime > plugins_mtime {
            // Cache is valid
            if let Ok(cache_content) = fs::read(&cache_path) {
                if let Ok(registry) = bincode::deserialize::<Registry>(&cache_content) {
                    return Ok(registry);
                }
            }
        }
    }
    
    // Build registry from scratch
    let mut registry = Registry {
        plugins: HashMap::new(),
        resolved_schemas: HashMap::new(),
    };
    
    if plugins_dir.exists() {
        // Load all plugins
        for entry in fs::read_dir(plugins_dir)? {
            let entry = entry?;
            if entry.path().is_dir() {
                if let Ok(plugin) = load_plugin(&entry.path()).await {
                    registry.plugins.insert(plugin.id.clone(), plugin);
                }
            }
        }
        
        // Resolve schema inheritance
        registry.resolved_schemas = resolve_all_schemas(&registry.plugins)?;
    }
    
    // Save to cache
    if let Ok(cache_content) = bincode::serialize(&registry) {
        let _ = fs::create_dir_all(cache_path.parent().unwrap());
        let _ = fs::write(&cache_path, cache_content);
    }
    
    Ok(registry)
}

async fn load_plugin(plugin_path: &Path) -> Result<Plugin> {
    let plugin_id = plugin_path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| AethelError::Other("Invalid plugin directory name".to_string()))?;
    
    let plugin_file = plugin_path.join("plugin.aethel.md");
    if !plugin_file.exists() {
        return Err(AethelError::PluginNotFound(plugin_id.to_string()));
    }
    
    let content = fs::read_to_string(&plugin_file)?;
    let (frontmatter, _) = parse_markdown_frontmatter(&content)?;
    
    let mut plugin = Plugin {
        id: plugin_id.to_string(),
        name: frontmatter.get("name")
            .and_then(|v| v.as_str())
            .unwrap_or(plugin_id)
            .to_string(),
        description: frontmatter.get("description")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string(),
        version: frontmatter.get("version")
            .and_then(|v| v.as_str())
            .unwrap_or("1.0")
            .to_string(),
        author: frontmatter.get("author")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string()),
        schemas: HashMap::new(),
    };
    
    // Load schemas
    let schemas_dir = plugin_path.join("schemas");
    if schemas_dir.exists() {
        for entry in fs::read_dir(schemas_dir)? {
            let entry = entry?;
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) == Some("md") {
                if let Ok(schema) = load_schema(&path).await {
                    plugin.schemas.insert(schema.name.clone(), schema);
                }
            }
        }
    }
    
    Ok(plugin)
}

async fn load_schema(schema_path: &Path) -> Result<Schema> {
    let content = fs::read_to_string(schema_path)?;
    let (frontmatter, _) = parse_markdown_frontmatter(&content)?;
    
    let name = schema_path
        .file_stem()
        .and_then(|n| n.to_str())
        .map(|s| s.replace(".aethel", ""))
        .ok_or_else(|| AethelError::Other("Invalid schema filename".to_string()))?;
    
    let fields = frontmatter.get("fields")
        .and_then(|v| v.as_sequence())
        .map(|seq| {
            seq.iter()
                .filter_map(|field| {
                    let field_map = field.as_mapping()?;
                    Some(SchemaField {
                        name: field_map.get("name")?.as_str()?.to_string(),
                        field_type: field_map.get("type")?.as_str()?.to_string(),
                        required: field_map.get("required")
                            .and_then(|v| v.as_bool())
                            .unwrap_or(false),
                        description: field_map.get("description")
                            .and_then(|v| v.as_str())
                            .map(|s| s.to_string()),
                        default: field_map.get("default").cloned(),
                    })
                })
                .collect()
        })
        .unwrap_or_default();
    
    Ok(Schema {
        name,
        extends: frontmatter.get("extends")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string()),
        description: frontmatter.get("description")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string()),
        fields,
    })
}

fn resolve_all_schemas(plugins: &HashMap<String, Plugin>) -> Result<HashMap<String, Vec<SchemaField>>> {
    let mut resolved = HashMap::new();
    let mut visited = HashSet::new();
    
    // Collect all schemas
    let mut all_schemas = HashMap::new();
    for plugin in plugins.values() {
        for (name, schema) in &plugin.schemas {
            all_schemas.insert(format!("{}/{}", plugin.id, name), schema.clone());
        }
    }
    
    // Add base schema fields
    let base_fields = vec![
        SchemaField {
            name: "uuid".to_string(),
            field_type: "string".to_string(),
            required: true,
            description: Some("Unique identifier for the artifact".to_string()),
            default: None,
        },
        SchemaField {
            name: "type".to_string(),
            field_type: "string".to_string(),
            required: true,
            description: Some("Type of the artifact".to_string()),
            default: None,
        },
        SchemaField {
            name: "createdAt".to_string(),
            field_type: "datetime".to_string(),
            required: true,
            description: Some("Creation timestamp".to_string()),
            default: None,
        },
        SchemaField {
            name: "updatedAt".to_string(),
            field_type: "datetime".to_string(),
            required: true,
            description: Some("Last update timestamp".to_string()),
            default: None,
        },
        SchemaField {
            name: "tags".to_string(),
            field_type: "array".to_string(),
            required: false,
            description: Some("Tags for the artifact".to_string()),
            default: Some(serde_yaml::Value::Sequence(vec![])),
        },
        SchemaField {
            name: "schemaVersion".to_string(),
            field_type: "string".to_string(),
            required: true,
            description: Some("Schema version".to_string()),
            default: None,
        },
    ];
    
    // Resolve each schema
    for schema_id in all_schemas.keys() {
        if !visited.contains(schema_id) {
            let fields = resolve_schema_fields(schema_id, &all_schemas, &mut visited, &base_fields)?;
            resolved.insert(schema_id.clone(), fields);
        }
    }
    
    Ok(resolved)
}

fn resolve_schema_fields(
    schema_id: &str,
    all_schemas: &HashMap<String, Schema>,
    visited: &mut HashSet<String>,
    base_fields: &[SchemaField],
) -> Result<Vec<SchemaField>> {
    if visited.contains(schema_id) {
        return Err(AethelError::CircularSchemaDependency(schema_id.to_string()));
    }
    
    visited.insert(schema_id.to_string());
    
    let schema = all_schemas.get(schema_id)
        .ok_or_else(|| AethelError::SchemaNotFound(schema_id.to_string()))?;
    
    let mut fields = if let Some(parent_id) = &schema.extends {
        resolve_schema_fields(parent_id, all_schemas, visited, base_fields)?
    } else {
        base_fields.to_vec()
    };
    
    // Apply child overrides
    for child_field in &schema.fields {
        if let Some(pos) = fields.iter().position(|f| f.name == child_field.name) {
            fields[pos] = child_field.clone();
        } else {
            fields.push(child_field.clone());
        }
    }
    
    Ok(fields)
}

fn parse_markdown_frontmatter(content: &str) -> Result<(serde_yaml::Value, String)> {
    let parts: Vec<&str> = content.splitn(3, "---").collect();
    if parts.len() < 3 {
        return Err(AethelError::Other("Invalid markdown format".to_string()));
    }
    
    let frontmatter: serde_yaml::Value = serde_yaml::from_str(parts[1])?;
    let body = parts[2].trim().to_string();
    
    Ok((frontmatter, body))
}

fn get_latest_mtime(dir: &Path) -> Result<SystemTime> {
    let mut latest = SystemTime::UNIX_EPOCH;
    
    for entry in WalkDir::new(dir) {
        if let Ok(entry) = entry {
            if let Ok(metadata) = entry.metadata() {
                if let Ok(mtime) = metadata.modified() {
                    if mtime > latest {
                        latest = mtime;
                    }
                }
            }
        }
    }
    
    Ok(latest)
}