# Aethel

A Git-native data vault with plugin-based architecture for building personal operating systems.

## Overview

Aethel is a high-performance command-line tool built in Rust that provides a structured, extensible foundation for managing personal data. It combines:

- **Git-Native Storage**: All data stored as plain text files in a Git repository
- **Plugin Architecture**: Extensible system for defining custom data types
- **SQLite Indexing**: Fast UUID-based lookups with local caching
- **LLM-First Design**: Optimized for programmatic interaction while remaining human-readable

## Installation

```bash
cargo build --release
```

## Quick Start

1. Initialize a new vault:
```bash
aethel init ~/my-vault
```

2. Create a new note:
```bash
aethel new --type note --title "My First Note"
```

3. Append content to an artifact:
```bash
aethel grow --uuid <uuid> --content "Additional content"
```

4. Retrieve an artifact:
```bash
aethel get --uuid <uuid>
```

5. Validate and maintain your vault:
```bash
aethel doctor --fix
```

## Architecture

The system consists of two main components:

1. **`aethel` CLI**: The open-source Rust tool (this repository)
2. **Aethel Vault**: Your private Git repository containing data and plugins

### Vault Structure

```
aethel_vault/
├── 00_inbox/          # Incoming data
├── 10_sources/        # Source materials by plugin
├── 20_artifacts/      # Processed artifacts by plugin
├── 30_knowledge/      # Extracted knowledge
├── 99_system/         # System configuration
│   └── plugins/       # Plugin definitions
└── .aethel/           # Internal state (not synced)
    ├── index.db       # SQLite artifact index
    └── registry.cache # Plugin cache
```

## Development

See [docs/sdd.md](docs/sdd.md) for detailed technical design and [docs/prd.md](docs/prd.md) for product requirements.