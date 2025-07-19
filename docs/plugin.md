---
role: developer_guide
task: create_aethel_plugins
target_audience: [plugin_developers, llms]
version: 1.0.0
date: 2025-07-19
---

# Aethel Plugin Development Guide

**Purpose:** Comprehensive guide for creating custom plugins to extend Aethel's data management capabilities.

## Quick Reference

```
PLUGIN_LOCATION: 99_system/plugins/{{PLUGIN_ID}}/
REQUIRED_FILES: plugin.aethel.md, schemas/*.aethel.md
SCHEMA_INHERITANCE: All schemas inherit base fields
NAMING_CONVENTION: lowercase_with_underscores
```

## Current Implementation Status

**Implemented:**
- ✅ Plugin discovery and loading
- ✅ Schema definition and inheritance
- ✅ Plugin-based artifact organization

**Not Yet Implemented:**
- ❌ Field validation and type checking
- ❌ Default value application
- ❌ Template support
- ❌ Schema versioning beyond "1.0"

## Table of Contents

1. [Plugin Architecture](#1-plugin-architecture)
2. [Creating a Plugin](#2-creating-a-plugin)
3. [Schema Definition](#3-schema-definition)
4. [Field Types](#4-field-types)
5. [Schema Inheritance](#5-schema-inheritance)
6. [Templates](#6-templates)
7. [Best Practices](#7-best-practices)
8. [Examples](#8-examples)
9. [Testing Plugins](#9-testing-plugins)
10. [Distribution](#10-distribution)

## 1. Plugin Architecture

### Core Concepts

| Concept | Description | Example |
|---------|-------------|---------|
| Plugin ID | Unique identifier | `productivity`, `bookmarks` |
| Schema | Artifact type definition | `task`, `bookmark`, `recipe` |
| Field | Data attribute | `title`, `due_date`, `priority` |
| Template | Boilerplate for new artifacts | `task_template.md` |

### Plugin Structure

```text title=plugin_directory_structure
99_system/plugins/{{PLUGIN_ID}}/
├── plugin.aethel.md       # Plugin metadata (REQUIRED)
├── schemas/               # Schema definitions (REQUIRED)
│   ├── schema1.aethel.md
│   └── schema2.aethel.md
└── templates/             # Optional templates
    └── schema1_template.md
```

### Plugin Loading Process

1. LOAD-1: Scan `99_system/plugins/` directory
2. LOAD-2: Parse `plugin.aethel.md` for metadata
3. LOAD-3: Load all schemas from `schemas/` directory
4. LOAD-4: Resolve schema inheritance
5. LOAD-5: Cache in `.aethel/registry.cache`

## 2. Creating a Plugin

### STEP-1: Create Plugin Directory

```bash title=create_plugin_dir.sh
mkdir -p ~/vault/99_system/plugins/{{PLUGIN_ID}}/schemas
```

### STEP-2: Create Plugin Metadata

**File:** `99_system/plugins/{{PLUGIN_ID}}/plugin.aethel.md`

```yaml title=plugin_metadata_template.yaml
---
name: {{Human Readable Name}}
version: {{SEMVER}}
description: {{Brief description}}
author: {{Your Name}} # Optional
---

# {{Plugin Name}}

## Overview

{{Detailed description of plugin purpose and use cases}}

## Provided Schemas

{{List of schemas this plugin provides}}

## Usage Examples

{{How to use the plugin's artifact types}}
```

### STEP-3: Define Schemas

Create schema files in `schemas/` directory.

## 3. Schema Definition

### Schema File Format

**File:** `99_system/plugins/{{PLUGIN_ID}}/schemas/{{SCHEMA_NAME}}.aethel.md`

```yaml title=schema_template.yaml
---
name: {{schema_name}}
extends: base # Optional, defaults to base
description: {{Schema description}}
fields:
  - name: {{field_name}}
    type: {{field_type}}
    required: {{true|false}}
    description: {{Field description}}
    default: {{default_value}} # Optional
---

# {{Schema Name}} Schema

## Description

{{Detailed description of this schema}}

## Field Reference

{{Detailed field documentation}}

## Examples

{{Example artifacts using this schema}}
```

### Base Schema Fields

All schemas automatically inherit these fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| uuid | string (UUID v4) | Yes (auto-generated) | Unique identifier |
| type | string | Yes | Artifact type (plugin_id/schema) |
| createdAt | string (ISO 8601) | Yes | Creation timestamp |
| updatedAt | string (ISO 8601) | Yes | Last update timestamp |
| tags | array[string] | No | Categorization tags |
| schemaVersion | string | Yes (auto-set) | Always "1.0" currently |

## 4. Field Types

### Supported Types

**Note:** Field types are currently for documentation purposes only. Type validation is not yet implemented.

| Type | Description | Example Value |
|------|-------------|---------------|
| string | Text data | `"Hello World"` |
| number | Numeric value | `42`, `3.14` |
| boolean | True/false | `true`, `false` |
| array | List of values | `["tag1", "tag2"]` |
| object | Nested structure | `{"key": "value"}` |
| date | ISO 8601 date | `"2024-01-20"` |
| datetime | ISO 8601 datetime | `"2024-01-20T10:30:00Z"` |

### Field Definition Properties

| Property | Required | Description | Currently Enforced |
|----------|----------|-------------|-------------------|
| name | Yes | Field identifier (lowercase_underscore) | ✅ Used for field storage |
| type | Yes | Data type from supported types | ❌ Stored but not validated |
| required | Yes | Whether field must be provided | ❌ Stored but not enforced |
| description | No | Human-readable description | ✅ For documentation |
| default | No | Default value if not provided | ❌ Stored but not applied |

## 5. Schema Inheritance

### Inheritance Rules

- INHERIT-1: All schemas inherit from `base` by default
- INHERIT-2: Child schemas inherit all parent fields
- INHERIT-3: Child can override parent field properties
- INHERIT-4: Child can add new fields
- INHERIT-5: Circular dependencies are forbidden

### Inheritance Example

```yaml title=parent_schema.yaml
---
name: content
description: Base content type
fields:
  - name: title
    type: string
    required: true
    description: Content title
  - name: body
    type: string
    required: false
    description: Main content
---
```

```yaml title=child_schema.yaml
---
name: article
extends: content
description: Long-form article
fields:
  - name: author
    type: string
    required: true
    description: Article author
  - name: published_date
    type: date
    required: false
    description: Publication date
---
```

## 6. Templates (Planned Feature)

**Note:** Template support is not yet implemented. This section describes the planned functionality.

Templates will provide starting content for new artifacts. The planned implementation includes:

- Template files in `99_system/plugins/{{PLUGIN_ID}}/templates/`
- Variable substitution for fields and metadata
- Automatic template selection based on schema

## 7. Best Practices

### Plugin Design

- PRACTICE-P1 (MUST): Use descriptive plugin IDs
- PRACTICE-P2 (MUST): Version plugins using semver
- PRACTICE-P3 (SHOULD): Group related schemas in one plugin
- PRACTICE-P4 (SHOULD): Provide comprehensive documentation
- PRACTICE-P5 (MAY): Include example artifacts

### Schema Design

- PRACTICE-S1 (MUST): Use lowercase_underscore for field names
- PRACTICE-S2 (MUST): Make only essential fields required
- PRACTICE-S3 (SHOULD): Provide sensible defaults
- PRACTICE-S4 (SHOULD): Keep schemas focused and cohesive
- PRACTICE-S5 (SHOULD): Document all fields thoroughly

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Plugin ID | lowercase_underscore | `task_management` |
| Schema name | lowercase_underscore | `daily_task` |
| Field name | lowercase_underscore | `due_date` |
| Plugin name | Title Case | `Task Management` |

## 8. Examples

### Example 1: Task Management Plugin

```yaml title=plugin.aethel.md
---
name: Task Management
version: 1.0.0
description: Track tasks, projects, and deadlines
author: Aethel Community
---

# Task Management Plugin

Provides schemas for personal task and project management.

## Schemas

- `task`: Individual tasks with status tracking
- `project`: Projects containing multiple tasks
- `milestone`: Key project milestones
```

```yaml title=schemas/task.aethel.md
---
name: task
description: Individual task with status tracking
fields:
  - name: title
    type: string
    required: true
    description: Task title
  - name: status
    type: string
    required: true
    description: Current status (open, in_progress, done, cancelled)
    default: open
  - name: priority
    type: string
    required: false
    description: Priority level (low, medium, high)
    default: medium
  - name: due_date
    type: date
    required: false
    description: Task deadline
  - name: assignee
    type: string
    required: false
    description: Person responsible
  - name: project_uuid
    type: string
    required: false
    description: UUID of parent project
---

# Task Schema

For tracking individual work items with status and priority.
```

### Example 2: Bookmark Plugin

```yaml title=plugin.aethel.md
---
name: Web Bookmarks
version: 1.0.0
description: Save and organize web bookmarks
---

# Web Bookmarks Plugin

Manage your web bookmarks with tags and descriptions.
```

```yaml title=schemas/bookmark.aethel.md
---
name: bookmark
description: Web bookmark with metadata
fields:
  - name: title
    type: string
    required: true
    description: Bookmark title
  - name: url
    type: string
    required: true
    description: Web URL
  - name: description
    type: string
    required: false
    description: Brief description
  - name: category
    type: string
    required: false
    description: Bookmark category
  - name: read
    type: boolean
    required: false
    description: Whether bookmark has been read
    default: false
---
```

## 9. Testing Plugins

### Validation Checklist

- [ ] Plugin directory exists at correct path
- [ ] plugin.aethel.md has valid YAML frontmatter
- [ ] All required metadata fields present
- [ ] Schema files have .aethel.md extension
- [ ] Schema YAML is valid
- [ ] No circular schema dependencies
- [ ] Field names follow conventions

**Note:** Field validation and type checking are not currently implemented. All fields passed with `--field` are stored without validation.

### Testing Commands

```bash title=test_plugin.sh
# Create test artifact (fields are not validated)
aethel new --type {{plugin_id}}/{{schema_name}} \
  --title "Test Artifact" \
  --field field1=value1 \
  --field any_field=any_value  # All fields accepted

# Verify plugin loaded
aethel doctor

# Check plugin appears in doctor output
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Plugin not found" | Missing plugin.aethel.md | Create metadata file |
| "Schema not found" | Schema file missing/misnamed | Check file exists in schemas/ |
| "Invalid YAML" | Syntax error in frontmatter | Validate YAML syntax |
| "Circular dependency" | Schema A extends B extends A | Remove circular reference |

## 10. Distribution

### Sharing Plugins

<<<DISTRIBUTION
To share a plugin:

1. Package plugin directory as archive
2. Document installation instructions
3. Include example usage
4. Specify Aethel version compatibility
DISTRIBUTION>>>

### Installation Instructions Template

```markdown title=install_instructions.md
# Installing {{Plugin Name}}

1. Download the plugin archive
2. Extract to your vault:
   ```bash
   tar -xzf {{plugin_id}}.tar.gz -C ~/vault/99_system/plugins/
   ```
3. Run doctor to verify:
   ```bash
   aethel doctor
   ```
4. Create your first artifact:
   ```bash
   aethel new --type {{plugin_id}}/{{schema_name}} --title "My First {{Type}}"
   ```
```

## Completion Checklist

- [ ] Plugin directory created
- [ ] plugin.aethel.md with valid metadata
- [ ] At least one schema defined
- [ ] All required fields documented
- [ ] Examples provided
- [ ] Tested with aethel new command

## Cross-References

- **CLI Usage:** See [usage.md](usage.md) for artifact commands
- **Project Overview:** See [README.md](../README.md)
- **Technical Design:** See [sdd.md](sdd.md) for architecture details