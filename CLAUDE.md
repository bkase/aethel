# CLAUDE.md - Aethel A4 Project

This file provides guidance for Claude Code when working with the Aethel A4 Rust project.

## Project Overview

**Aethel A4** is a Rust-based personal knowledge base system that implements a plain-Markdown, Git-native protocol for managing personal notes and knowledge. The project is designed to be:

- **App-agnostic**: Uses ordinary `.md` files in standard folders
- **Daily-first**: Daily notes are the primary capture surface
- **Low-friction**: Supports append-only operations to known anchors/sections
- **Git-native**: Uses Git for multi-device synchronization

## Project Structure

This is a Rust workspace with the following planned structure:

```
aethel/
├── crates/
│   ├── aethel-core/    # Core library (vault resolution, Git sync, etc.)
│   └── aethel-cli/     # CLI binary built on aethel-core
├── docs/               # Documentation
│   ├── protocol.md     # A4 protocol specification
│   └── sdd.md         # Software design document
├── Cargo.toml         # Workspace configuration
├── Makefile           # Build and development commands
└── rust-toolchain.toml # Rust version pinning (1.88.0)
```

**Note**: The crates directory may not exist yet as this appears to be in early development.

## Development Environment

- **Rust Version**: 1.88.0 (pinned in rust-toolchain.toml)
- **Tool Management**: Uses `mise` for managing Rust and other tools
- **Components**: rustfmt, clippy (minimal profile)

## Build and Development Commands

Use the provided Makefile for all common development tasks:

### Primary Commands
- `make all` - Complete development workflow (build + fmt + lint + test)
- `make build` - Build the workspace in debug mode
- `make release` - Build the workspace in release mode
- `make check` - Check for compilation errors without building binaries

### Code Quality
- `make fmt` - Check code formatting (fails if unformatted)
- `make fmt-fix` - Fix code formatting issues
- `make lint` - Run clippy linter (treats warnings as errors)

### Testing
- `make test` - Run all tests in the workspace
- `make nextest` - Run tests with cargo-nextest (if installed, recommended for speed)

### Maintenance
- `make clean` - Clean build artifacts
- `make audit` - Run security audit (requires cargo-audit)
- `make udeps` - Find unused dependencies (requires cargo-udeps)

## Key Dependencies

### Core Functionality
- **Git Backend**: Will use `gix` (gitoxide) for pure Rust Git operations
- **Serialization**: serde, serde_json, serde_yaml
- **CLI**: clap with derive features
- **Error Handling**: thiserror, anyhow

### Development/Testing
- **Testing**: rstest, insta (snapshot testing), assert_cmd, predicates
- **Logging**: tracing, tracing-subscriber

## Planned CLI Interface

The CLI will implement these core commands:
- `a4 today` - Resolve/create today's note (template or blank)
- `a4 append` - Append anchored blocks to notes with heading support
- `a4 sync` - Git-based synchronization (fast-forward only, no complex merges)

## Git Integration Strategy

- **Primary**: Uses `gix` (gitoxide) for pure Rust Git operations
- **No Subprocesses**: All Git operations through Rust libraries
- **Sync Strategy**: Fast-forward only for v1 (errors on divergent histories)
- **Future**: May add libgit2 backend via Cargo features for advanced merge operations

## Testing Strategy

- **Golden Tests**: Uses insta for snapshot testing
- **CLI Testing**: Uses assert_cmd and predicates for CLI integration tests
- **Unit Tests**: Standard Rust testing with rstest for parameterized tests

## Important Considerations

1. **No Complex Merges**: V1 implements fetch + fast-forward or error approach
2. **Static Builds**: Preference for pure Rust dependencies to avoid C dependencies
3. **Cross-Platform**: Targets macOS, Linux, Windows
4. **Markdown-Centric**: All operations work with plain Markdown files
5. **Git-Native**: Designed to work seamlessly with Git workflows

## Development Workflow

1. **Setup**: Run `mise install` to get the correct Rust toolchain
2. **Development**: Use `make all` for complete validation
3. **Testing**: Use `make nextest` for fast test runs (if available)
4. **CI**: GitHub Actions runs fmt, lint, test, and build checks

## Documentation

- `docs/protocol.md` - Complete A4 protocol specification
- `docs/sdd.md` - Software design document with implementation details

## Branch Strategy

- **Main Branch**: `main` - primary development branch
- **Current Branch**: `a4-version` - current working branch

When working on this project, always run the full `make all` suite before committing to ensure code quality standards are met.