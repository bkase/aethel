# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Aethel is a personal operating system project that aims to create a Git-native data vault with a plugin-based architecture. The project consists of:
- **aethel**: A Rust-based CLI tool for managing the vault
- **Aethel Vault**: A Git repository containing personal data organized by plugins

## Architecture

### Core Components
- **SQLite Database**: Local index for fast querying of vault artifacts
- **Plugin System**: Extensible architecture where plugins manage specific data types
- **Git-Native Storage**: All data stored as files in a Git repository
- **Artifact Index**: Caches artifact metadata for performance

### Technology Stack
- **Language**: Rust
- **Async Runtime**: tokio
- **Database**: SQLite with sqlx
- **CLI Framework**: clap
- **Git Operations**: git2
- **Serialization**: serde with JSON/TOML support

## Commands

Since this is a Rust project in development, common commands will be:

```bash
# Build the project
cargo build

# Run tests
cargo test

# Run with debug output
RUST_LOG=debug cargo run -- <command>

# Format code
cargo fmt

# Lint code
cargo clippy
```

### CLI Usage Examples

```bash
# Create a new artifact with initial content
cargo run -- new --type note --title "My Note" --body "Initial content here"

# Create empty artifact (backward compatible)
cargo run -- new --type note --title "Empty Note"

# Append to existing artifact
cargo run -- grow --uuid <UUID> --content "Additional content"
```

## Key Design Principles

1. **Tool-Data Decoupling**: The CLI tool and vault repository are separate
2. **Git-Native**: All operations leverage Git for versioning and synchronization
3. **Plugin-Based**: Each data type is managed by a dedicated plugin
4. **Local-First**: SQLite index enables offline operation with fast queries

## Module Structure

When implementing, organize code into these modules:
- `cli/` - Command parsing and execution
- `config/` - Configuration management
- `db/` - Database operations and schema
- `error/` - Error types and handling
- `plugin/` - Plugin management and registry
- `sync/` - Git synchronization logic
- `models/` - Data structures for artifacts and plugins

## Important Implementation Notes

1. **Error Handling**: Use a custom error type that implements std::error::Error
2. **Async Operations**: Most operations should be async, especially file I/O and Git operations
3. **Database Schema**: The artifact index includes path, plugin_id, metadata (JSON), and timestamps
4. **Plugin Discovery**: Plugins are discovered from a `plugins/` directory in the vault
5. **Synchronization**: Pull before push, handle merge conflicts for the index database
6. **Artifact Path Format**: Artifacts are stored at `20_artifacts/{plugin_id}/{YYYY}/{MM}/{DDTHH-MM-SSZ}.md`
   - Example: `20_artifacts/core_note/2025/07/19T14-30-45Z.md`
   - Year/month directories provide chronological organization
   - ISO timestamp format for consistent sorting