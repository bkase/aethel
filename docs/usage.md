---
role: user_guide  
task: operate_aethel_cli
target_audience: [humans, llms]
version: 1.0.0
date: 2025-07-19
---

# Aethel CLI Usage Guide

**Purpose:** Complete reference for operating Aethel's command-line interface for Git-native data vault management.

## Quick Reference

```
COMMANDS: init | new | grow | get | doctor
ARTIFACT_TYPE: plugin_id/schema_name or schema_name
UUID_FORMAT: 123e4567-e89b-12d3-a456-426614174000
DEFAULT_PLUGIN: core_note
```

## Table of Contents

1. [Installation](#1-installation)
2. [Core Concepts](#2-core-concepts)
3. [Command Reference](#3-command-reference)
4. [Artifact Operations](#4-artifact-operations)
5. [Plugin Usage](#5-plugin-usage)
6. [Vault Structure](#6-vault-structure)
7. [Common Workflows](#7-common-workflows)
8. [Troubleshooting](#8-troubleshooting)
9. [Best Practices](#9-best-practices)

## 1. Installation

### Requirements

- REQ-INSTALL-1 (MUST): Rust toolchain >= 1.70.0
- REQ-INSTALL-2 (MUST): Git >= 2.25.0  
- REQ-INSTALL-3 (SHOULD): SQLite >= 3.35.0

### Build Instructions

```bash title=install.sh
# Clone repository
git clone https://github.com/your-org/aethel.git
cd aethel

# Build release binary
cargo build --release

# Install to PATH (optional)
cargo install --path .
```

### Verification

```bash
aethel --version
# Expected: aethel 0.1.0
```

## 2. Core Concepts

### Configuration

Aethel stores configuration in platform-specific locations:
- Linux/Unix: `~/.config/aethel/config.json`
- macOS: `~/Library/Application Support/aethel/config.json`
- Windows: `%APPDATA%\aethel\config.json`

Configuration file format:
```json
{
  "vault_path": "/absolute/path/to/vault"
}
```

The `AETHEL_VAULT` environment variable overrides the configured path.

### Key Terms

| Term | Definition | Example |
|------|------------|---------|  
| Vault | Git repository containing all data | `~/my-vault/` |
| Artifact | Single data unit with metadata | Note, task, bookmark |
| Plugin | Schema provider for artifact types | `core_note`, `productivity` |
| UUID | Unique identifier for artifacts | `123e4567-e89b-12d3-a456-426614174000` |
| Schema | Structure definition for artifact type | `note.aethel.md` |

### Initialization

<<<INITIALIZATION
Create new Aethel vault with required structure:

```bash
aethel init {{VAULT_PATH}}
```

Creates:
- Vault directory structure
- Git repository  
- SQLite index (.aethel/index.db)
- Default core_note plugin
- Initial commit
INITIALIZATION>>>

### Directory Layout

```text title=vault_structure
vault/
├── 00_inbox/          # Incoming data staging
├── 10_sources/        # Raw materials by plugin
├── 20_artifacts/      # Structured artifacts by plugin  
├── 30_knowledge/      # Synthesized insights
├── 99_system/         # Configuration
│   └── plugins/       # Plugin definitions
└── .aethel/           # Local cache (gitignored)
    ├── index.db       # SQLite index
    └── registry.cache # Plugin cache
```

## 3. Command Reference

### CMD-1: aethel init

**Syntax:** `aethel init <path>`

**Purpose:** Initialize new Aethel vault at specified location.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| path | string | Yes | Target directory for vault |

**Example:**
```bash title=init_example.sh
aethel init ~/Documents/my-knowledge-base
```

**Post-conditions:**
- Directory exists with correct structure
- Git repository initialized
- SQLite database created
- core_note plugin installed
- Configuration saved to ~/.config/aethel/config.json

**Output:**
```text
Initialized new Aethel vault at: /path/to/vault
Configuration saved to: ~/.config/aethel/config.json
```

### CMD-2: aethel new

**Syntax:** `aethel new --type <TYPE> [OPTIONS]`

**Purpose:** Create new artifact with specified type and metadata.

**Parameters:**
| Parameter | Flag | Required | Format | Description |
|-----------|------|----------|--------|-------------|
| type | -t, --type | Yes | plugin_id/schema or schema | Artifact type |
| title | --title | No | string | Artifact title |
| field | -f, --field | No | key=value | Custom field (repeatable) |
| body | --body | No | string | Initial content for the artifact |

**Type Resolution:**
- Full format: `plugin_id/schema_name`
- Short format: `schema_name` (defaults to core_note plugin)

**Examples:**
```bash title=new_examples.sh
# Create simple note
aethel new --type note --title "Meeting Notes"

# Create note with initial content
aethel new --type note --title "Quick Thought" \
  --body "This is my initial idea that I want to capture immediately."

# Create with custom fields
aethel new --type note --title "Project Ideas" \
  --field priority=high \
  --field category=work

# Create with both body and custom fields
aethel new --type note --title "Design Document" \
  --body "## Overview\n\nThis document describes the architecture..." \
  --field status=draft \
  --field version=1.0

# Use custom plugin
aethel new --type productivity/task \
  --title "Fix authentication bug" \
  --field status=open \
  --field assignee=alice
```

**Output:** UUID of created artifact on stdout (single line).

### CMD-3: aethel grow  

**Syntax:** `aethel grow --uuid <UUID> --content <CONTENT>`

**Purpose:** Append content to existing artifact.

**Parameters:**
| Parameter | Flag | Required | Format | Description |
|-----------|------|----------|--------|-------------|
| uuid | --uuid | Yes | UUID v4 | Target artifact identifier |
| content | --content | Yes | string | Content to append |

**Behavior:**
- GROW-1: Appends content after newline
- GROW-2: Updates `updatedAt` timestamp
- GROW-3: Preserves existing metadata
- GROW-4: Creates new Git commit

**Example:**
```bash title=grow_example.sh  
aethel grow \
  --uuid 123e4567-e89b-12d3-a456-426614174000 \
  --content "Additional thoughts on implementation approach"
```

**Common Errors:**
- Invalid UUID format
- Artifact not found with given UUID

### CMD-4: aethel get

**Syntax:** `aethel get --uuid <UUID> [--format <FORMAT>]`

**Purpose:** Retrieve artifact by UUID.

**Parameters:**
| Parameter | Flag | Required | Default | Options | Description |
|-----------|------|----------|---------|---------|-------------|
| uuid | --uuid | Yes | - | UUID v4 | Artifact identifier |
| format | --format | No | markdown | markdown, json | Output format |

**Output Formats:**

1. **Markdown Format (default):**
   ```markdown
   ---
   uuid: {{UUID}}
   type: {{TYPE}}
   # ... other metadata
   ---
   
   # Content here
   ```

2. **JSON Format:**
   ```json
   {
     "frontmatter": {
       "uuid": "{{UUID}}",
       "type": "{{TYPE}}",
       "createdAt": "{{ISO_8601}}",
       "updatedAt": "{{ISO_8601}}",
       "tags": [],
       "schemaVersion": "1.0"
     },
     "content": "{{CONTENT}}",
     "path": "{{RELATIVE_PATH}}"
   }
   ```

**Examples:**
```bash title=get_examples.sh
# Get as Markdown
aethel get --uuid 123e4567-e89b-12d3-a456-426614174000

# Get as JSON for processing
aethel get --uuid 123e4567-e89b-12d3-a456-426614174000 \
  --format json | jq '.metadata.title'
```

### CMD-5: aethel doctor

**Syntax:** `aethel doctor [--fix] [--rebuild-index]`

**Purpose:** Validate vault integrity and repair issues.

**Parameters:**
| Parameter | Flag | Description |
|-----------|------|-------------|
| fix | --fix | Auto-repair detected issues |
| rebuild-index | --rebuild-index | Recreate index from files |

**Validation Checks:**

| Component | Description | Auto-fixable |
|-----------|-------------|--------------|  
| Directories | All required directories exist | Yes |
| Git | Repository properly initialized | No |
| Index | SQLite database accessible | Yes |
| Registry | Plugin cache valid | Yes |
| Artifacts | Valid format and timestamps | Yes |
| Sync | Files match database index | Yes |

**Examples:**
```bash title=doctor_examples.sh
# Check only
aethel doctor

# Fix issues
aethel doctor --fix

# Full rebuild after manual edits
aethel doctor --rebuild-index
```

**Output:**
```text
✓ Directory exists: 00_inbox
✓ Directory exists: 10_sources
✓ Directory exists: 20_artifacts
✓ Directory exists: 30_knowledge
✓ Directory exists: 99_system
✓ Directory exists: .aethel
✓ Loaded 1 plugins
⚠️  Invalid timestamp in: 20_artifacts/core_note/...
  ✓ Fixed timestamp

=== Summary ===
Total issues found: 1
Issues fixed: 1
```

## 4. Artifact Operations

### Artifact Schema

<<<ARTIFACT_STRUCTURE
Base artifact structure (all types inherit):

```yaml title=artifact_template.md
---
uuid: {{UUID_V4}}
type: {{PLUGIN_ID}}/{{SCHEMA_NAME}}
createdAt: {{ISO_8601_UTC}}
updatedAt: {{ISO_8601_UTC}}
tags: [{{TAG_LIST}}]
schemaVersion: 1.0
# Plugin-specific fields below
{{CUSTOM_FIELDS}}
---

# Main content in Markdown
{{CONTENT}}
```
ARTIFACT_STRUCTURE>>>

### Artifact Lifecycle

| Stage | Command | Description |
|-------|---------|-------------|
| Create | `aethel new` | Generate UUID, initialize metadata |
| Update | `aethel grow` | Append content, update timestamp |
| Read | `aethel get` | Retrieve by UUID |
| Delete | Manual removal | Delete file, run doctor |

### Locating Artifacts

**Method 1: File System Browse**
```bash title=browse_artifacts.sh
# List all artifacts for a plugin
ls -la ~/vault/20_artifacts/core_note/2025/07/
```

**Method 2: Content Search**
```bash title=search_artifacts.sh  
# Search by content
grep -r "search term" ~/vault/20_artifacts/

# Search by UUID
find ~/vault -name "*123e4567*.md"
```

**Method 3: Git History**
```bash title=git_search.sh
# Find recently modified
git -C ~/vault log --name-only --pretty=format: | \
  grep "20_artifacts" | head -20
```

### UUID Requirements

- FORMAT: Standard UUID v4 (RFC 4122)
- EXAMPLE: `123e4567-e89b-12d3-a456-426614174000`
- VALIDATION: 8-4-4-4-12 hexadecimal pattern
- CASE: Lowercase preferred

## 5. Plugin Usage

### Default Plugin

**Plugin ID:** `core_note`  
**Provided Types:** `note`

```bash title=use_default_plugin.sh
# Short form (implicit core_note)
aethel new --type note --title "Daily Note"

# Explicit form  
aethel new --type core_note/note --title "Daily Note"
```

### Custom Plugin Types

**Type Format:** `{{PLUGIN_ID}}/{{SCHEMA_NAME}}`

```bash title=use_custom_plugins.sh
# Explicit plugin reference
aethel new --type productivity/task \
  --title "Implement caching" \
  --field priority=high \
  --field due_date=2024-02-01

# Short form (if schema name unique)
aethel new --type task --title "Review PR #123"
```

### Schema Discovery

**Location:** `99_system/plugins/{{PLUGIN_ID}}/schemas/{{SCHEMA}}.aethel.md`

**Schema Structure:**
```yaml title=schema_example.yaml
---
name: task
extends: base  # Optional inheritance
fields:
  - name: priority
    type: string
    required: true
    description: Task priority level
    default: medium
---
```

### Field Validation

| Validation | Description | Example |
|------------|-------------|---------|  
| Required | Field must be provided | `title` for notes |
| Type | Value must match type | string, number, boolean |
| Default | Used if not specified | `priority: medium` |

**See:** [Plugin Development Guide](plugin.md) for creating plugins.

## 6. Vault Structure  

### Directory Reference

| Directory | Purpose | Git Tracked | Example Content |
|-----------|---------|-------------|----------------|
| 00_inbox/ | Temporary staging | Yes | Incoming data |
| 10_sources/ | Raw materials | Yes | PDFs, images |
| 20_artifacts/ | Structured data | Yes | Notes, tasks |
| 30_knowledge/ | Insights | Yes | Connections |
| 99_system/ | Configuration | Yes | Plugins |
| .aethel/ | Local cache | No | index.db |

### Artifact Path Format

```text
20_artifacts/{{PLUGIN_ID}}/{{YYYY}}/{{MM}}/{{DDTHH-MM-SSZ}}.md
```

**Example Path:**
```text
20_artifacts/core_note/2025/07/19T14-30-45Z.md
```

### Storage Rules

- STORAGE-1: Artifacts grouped by plugin
- STORAGE-2: Date hierarchy for scalability  
- STORAGE-3: Filename includes type and UUID
- STORAGE-4: All content in Markdown + YAML

## 7. Common Workflows

### WORKFLOW-1: Daily Notes

```bash title=daily_note_workflow.sh
# Option A: Create with initial content using --body
UUID=$(aethel new --type note \
  --title "Daily Note $(date +%Y-%m-%d)" \
  --body "## Schedule\n- 09:00 Team standup\n- 14:00 Design review")

# Option B: Create empty and grow throughout day
UUID=$(aethel new --type note \
  --title "Daily Note $(date +%Y-%m-%d)")

# Append throughout day (silent on success)
aethel grow --uuid $UUID \
  --content "09:00 - Team standup notes..."

aethel grow --uuid $UUID \
  --content "14:00 - Design review decisions..."
```

### WORKFLOW-2: Task Management

```bash title=task_workflow.sh
# Create task with metadata
aethel new --type productivity/task \
  --title "Implement user authentication" \
  --field priority=high \
  --field status=open \
  --field assignee=$USER

# Update task progress
aethel grow --uuid {{TASK_UUID}} \
  --content "Completed OAuth integration"
```

### WORKFLOW-3: Knowledge Graph

```bash title=knowledge_workflow.sh  
# Create connected notes
NOTE1=$(aethel new --type note \
  --title "Machine Learning Basics" \
  --field category=ai)

NOTE2=$(aethel new --type note \
  --title "Neural Networks" \
  --field category=ai)

# Link notes via content
aethel grow --uuid $NOTE2 \
  --content "Builds on concepts from [[$NOTE1]]"
```

### WORKFLOW-4: Batch Operations

```bash title=batch_import.sh
# Import multiple files with content
for file in documents/*.txt; do
  TITLE=$(basename "$file" .txt)
  CONTENT=$(cat "$file")
  
  # Create note with content in one step
  UUID=$(aethel new --type note --title "$TITLE" --body "$CONTENT")
  
  echo "Imported: $TITLE ($UUID)"
done

# Alternative: Create empty then grow (for large files)
for file in documents/*.txt; do
  TITLE=$(basename "$file" .txt)
  CONTENT=$(cat "$file")
  
  # Create note and capture UUID
  UUID=$(aethel new --type note --title "$TITLE")
  
  # Add content
  aethel grow --uuid "$UUID" --content "$CONTENT"
  
  echo "Imported: $TITLE ($UUID)"
done
```

## 8. Troubleshooting

### Common Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| "Artifact not found with UUID: {uuid}" | Invalid/missing artifact | Verify UUID exists |
| "Plugin not found: {plugin}" | Unknown plugin | Check plugin exists in 99_system/plugins/ |
| "Invalid UUID: {uuid}" | Malformed UUID | Use valid UUID v4 format |
| "Database error" | Corrupted index | Run `doctor --rebuild-index` |
| "Configuration not found" | No vault initialized | Run `aethel init` first |

### Diagnostic Commands

```bash title=diagnostics.sh
# Check system health
aethel doctor

# Enable debug logging
RUST_LOG=debug aethel new --type note

# Verify Git status
cd ~/vault && git status

# Check index integrity  
sqlite3 ~/vault/.aethel/index.db "PRAGMA integrity_check;"
```

### Recovery Procedures

**RECOVERY-1: Corrupted Index**
```bash
aethel doctor --rebuild-index
```

**RECOVERY-2: Missing Plugin**
```bash
# Refresh plugin cache
rm ~/vault/.aethel/registry.cache
aethel doctor --fix
```

**RECOVERY-3: Sync Issues**
```bash
# Reset to clean state
git -C ~/vault reset --hard HEAD
aethel doctor --rebuild-index
```

## 9. Best Practices

### For Human Users

- PRACTICE-H1 (MUST): Commit changes frequently
- PRACTICE-H2 (MUST): Use descriptive artifact titles
- PRACTICE-H3 (SHOULD): Maintain consistent tag taxonomy
- PRACTICE-H4 (SHOULD): Group related schemas in plugins
- PRACTICE-H5 (MAY): Use Git branches for experiments

### For LLMs

- PRACTICE-L1 (MUST): Always use complete UUID format
- PRACTICE-L2 (MUST): Validate required fields before creation
- PRACTICE-L3 (MUST): Use full type format when ambiguous
- PRACTICE-L4 (SHOULD): Check schema before adding fields
- PRACTICE-L5 (SHOULD): Parse error messages for field names

### Performance Optimization

| Action | Frequency | Impact |
|--------|-----------|--------|
| Run `aethel doctor` | Weekly | Index accuracy |
| Git garbage collection | Monthly | Repository size |
| Backup `.aethel/` | Before upgrades | Fast recovery |

### Security Considerations

<<<SECURITY
- Never store secrets in artifact content
- Use `.gitignore` for sensitive files
- Encrypt vault repository for cloud sync
- Audit plugin code before installation
SECURITY>>>

## Environment Variables

| Variable | Values | Default | Purpose |
|----------|--------|---------|---------|  
| RUST_LOG | error, warn, info, debug, trace | error | Logging verbosity |
| AETHEL_VAULT | Path string | None | Override vault location (takes precedence over config) |

## Automation Examples

### Shell Script Integration

```bash title=automation_example.sh
#!/bin/bash
# Create timestamped note with content and capture UUID

# Method 1: With initial content
UUID=$(aethel new \
  --type note \
  --title "Automated Import $(date +%Y%m%d_%H%M%S)" \
  --body "Import started at $(date)")

# Method 2: Parse UUID from output (works with or without --body)
UUID=$(aethel new \
  --type note \
  --title "Automated Import $(date +%Y%m%d_%H%M%S)" | \
  grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}')

if [ -n "$UUID" ]; then
  echo "Created artifact: $UUID"
  # Further processing...
fi
```

### JSON Processing Pipeline

```bash title=json_pipeline.sh  
# Extract and transform artifact data
aethel get --uuid {{UUID}} --format json | \
  jq '{
    title: .metadata.title,
    created: .metadata.createdAt,
    wordCount: (.content | split(" ") | length)
  }'
```

## Completion Checklist

- [ ] All commands documented with examples
- [ ] Error codes enumerated  
- [ ] Workflows demonstrate real usage
- [ ] Best practices cover humans and LLMs
- [ ] Troubleshooting includes recovery steps

## Cross-References

- **Plugin Development:** See [plugin.md](plugin.md)
- **Technical Design:** See [sdd.md](sdd.md)  
- **Project Overview:** See [README.md](../README.md)