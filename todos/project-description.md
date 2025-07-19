# Project: Aethel

A Git-native personal data vault with plugin architecture for managing personal knowledge as a "personal operating system"

## Features

- Git-native storage with version control
- Plugin-based extensible architecture
- High-performance SQLite indexing
- UUID-based permanent identity system
- Human-readable Markdown with YAML frontmatter
- CLI for creating, managing, and querying artifacts

## Tech Stack

- Language: Rust (Edition 2021)
- Async Runtime: tokio
- Database: SQLite with sqlx
- CLI Framework: clap (derive)
- Git Operations: git2
- Serialization: serde (JSON/YAML)
- Error Handling: thiserror, anyhow

## Structure

- `src/main.rs` - Entry point
- `src/cli.rs` - Command definitions
- `src/commands/` - Command implementations
- `src/models.rs` - Domain entities
- `src/store.rs` - File repository
- `src/index.rs` - SQLite operations
- `src/registry.rs` - Plugin management
- `docs/` - PRD and SDD documentation

## Architecture

- Layered architecture with clear separation
- Repository pattern for storage abstraction
- Plugin system with schema inheritance
- Hybrid storage: Git files + SQLite index
- Async operations for I/O

## Commands

- Build: `cargo build`
- Test: `cargo test`
- Lint: `cargo clippy`
- Format: `cargo fmt`
- Run: `cargo run -- <command>`
- Debug run: `RUST_LOG=debug cargo run -- <command>`

## Testing

Currently no tests exist. To create tests:

- Unit tests: Add `#[cfg(test)]` modules in source files
- Integration tests: Create `tests/` directory
- Use `#[tokio::test]` for async tests
- Use tempfile for isolated test environments

## Editor

- Open folder: tell me to open nvim and I will myself

