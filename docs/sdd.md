### **Software Design Document (SDD): Aethel**

**Version:** 1.5 (Hardened)
**Status:** Approved for Implementation
**Author:** Lead Architect
**Related PRD:** Aethel PRD v1.5
**Note:** This version supersedes all previous SDDs. It specifies a **SQLite database** for the artifact index instead of a JSON file, laying a more robust foundation for future indexing capabilities. It also retains all critical architectural hardening from the v1.4 critique.

#### 1. Introduction & Overview

This document outlines the software design for the **`aethel`**, a high-performance command-line interface built in Rust. This tool serves as the canonical programmatic gateway to a user's private **Aethel Vault**.

The core design centers on a complete decoupling of the open-source tool from the private user data. The tool is stateless and generic; the vault is stateful and its structure is defined by a dynamic, user-configurable plugin system. This design prioritizes architectural robustness, data integrity, performance, and ultimate extensibility.

#### 2. Architectural Goals & Constraints

- **Correctness & Safety:** The system must be reliable. Rust's safety guarantees are foundational.
- **Scalable Performance:** CLI operations must remain instantaneous (<100ms) regardless of vault size. **This is a non-negotiable goal, addressed by a SQLite index and registry caching.**
- **Data Integrity:** The system must protect user data. Operations that modify data must be transparent, atomic, and auditable.
- **Dynamic Extensibility:** The CLI must support new data types via a plugin system without requiring a recompile.
- **Data Portability & Longevity:** The core data format remains non-proprietary plain text.
- **Concurrency & Sync Safety:** The system is designed for multi-device use via Git, reinforced by a strict synchronization protocol.

#### 3. High-Level System Architecture

The architecture remains decoupled but now includes a critical hidden directory within the vault for system use, containing a SQLite database for indexing.

1. **`aethel`:** The stateless Rust binary.
2. **Configuration File:** (`~/.config/aethel/config.json`) The bridge between the tool and the vault.
3. **Aethel Vault:** The user-owned Git repository. It now contains a `.aethel/` directory for internal state management.

```
+-----------------+      Reads Path      +----------------------+
|     aethel      | <------------------+ |  Configuration File  |
| (Rust Binary)   |                      | (~/.config/aethel/*) |
+-----------------+      Manages         +----------------------+
        |                                          |
        +----------------------------------------->+
                                                   |
                                     +-------------v--------------+
                                     |       Aethel Vault       |
                                     |    (Git Repository)      |
                                     | +----------------------+ |
                                     | | .aethel/             | |
                                     | |  - index.db          | |
                                     | |  - registry.cache    | |
                                     | +----------------------+ |
                                     +--------------------------+
```

#### 4. The `.aethel` System Directory

To solve critical performance and state management issues, a hidden `.aethel/` directory will be created at the vault root.

- **Purpose:** Stores indexes, caches, and other machine-generated files. It is not intended for direct user interaction.
- **Git Management:** The `aethel init` command will automatically create a `.gitignore` file in the vault root containing the line `.aethel/`. This internal state is local to each machine and will be rebuilt as needed, preventing sync conflicts.

#### 5. Detailed Data Model & Architecture

##### 5.1. Artifact Index (`.aethel/index.db`)

To eliminate catastrophic O(N) filesystem scans, a SQLite database will be used for UUID-to-filepath mapping.

- **File:** `<vault_root>/.aethel/index.db`
- **Database Schema:** A single table will be used for the index.

  ```sql
  CREATE TABLE IF NOT EXISTS artifacts (
      uuid TEXT PRIMARY KEY NOT NULL,
      filepath TEXT NOT NULL
  );
  ```

- **Interaction Logic:**
  - **`aethel new`:** After creating a file, executes:
    `INSERT INTO artifacts (uuid, filepath) VALUES (?, ?);`
  - **`aethel get`/`grow`:** To find a file path, executes:
    `SELECT filepath FROM artifacts WHERE uuid = ?;`
  - **`aethel doctor --rebuild-index`:** Drops the existing table, recreates it, performs a full filesystem walk of the vault, and executes an `INSERT` statement for each artifact found.

##### 5.2. Plugin & Schema Registry Caching (`.aethel/registry.cache`)

To eliminate redundant parsing of schema files on every run.

- **Format:** A binary serialization of the in-memory `Registry` struct (using `bincode`).
- **Caching Logic (`registry::load()`):**
  1. Check if `registry.cache` exists.
  2. If it exists, compare the `mtime` of the cache file with the `mtime` of the `<vault_root>/99_system/plugins/` directory.
  3. **Cache Hit:** If the cache is newer, deserialize the cache file and use the `Registry`.
  4. **Cache Miss:** Otherwise, rebuild the `Registry` from the filesystem and overwrite `registry.cache`.

##### 5.3. Schema Inheritance Resolution Strategy

The `registry::load()` function will resolve the `extends` logic with the following deterministic rules:

1. **Field Merging:** The final field list for a schema is the union of its own `fields` and the final fields of its parent.
2. **Conflict Policy (Child Overrides):** If a field with the same `name` exists in both the child and the parent schema, the child's definition **completely overwrites** the parent's definition.
3. **Circular Dependency Detection:** A Depth-First Search will be used to resolve the `extends` chain. If a back-edge is detected, the process will fail with a `CircularSchemaDependency` error.

#### 6. Core Component Design: `aethel`

##### 6.1. Technology Stack

- **Language:** Rust (Latest Stable Edition)
- **Async Runtime:** `tokio`
- **Core Libraries:**
  - `clap`: For argument parsing.
  - `serde`, `serde_yaml`: For YAML serialization.
  - `sqlx`: (with `sqlite` and `runtime-tokio-rustls` features) For all SQLite interactions.
  - `git2`: For programmatic Git operations.
  - `uuid`: For generating new UUIDs.
  - `chrono`: For timestamps.
  - `walkdir`: For directory traversal.
  - `thiserror`: For custom error types.
  - `xdg`: For config directory location.
  - `bincode`: For registry caching.

##### 6.2. Proposed Module Structure

```
aethel/
└── src/
    ├── main.rs         # Async entry point, argument parsing, top-level error handling
    ├── cli.rs          # Defines the clap command structure
    ├── commands/       # Module for async command implementations
    │   ├── init.rs, new.rs, grow.rs, get.rs, doctor.rs
    ├── store.rs        # Vault path resolution and raw file I/O
    ├── index.rs        # Manages the SQLite database connection pool and queries
    ├── registry.rs     # Manages the Plugin/Schema Registry, caching, and inheritance
    ├── models.rs       # Struct definitions for data models
    ├── error.rs        # Custom error enum for the application
    └── utils.rs        # Shared helper functions
```

##### 6.3. Command Implementation Logic (Hardened)

- **`aethel init <path>`**
  1. Creates the full directory tree, including `.aethel/`.
  2. Creates the `.gitignore` file.
  3. Establishes a connection to `<path>/.aethel/index.db` and executes the `CREATE TABLE` SQL statement.
  4. Creates the example `core_note` plugin.
  5. Updates global config and initializes Git repo.

- **`aethel get --uuid <uuid>`**
  1. Establish a connection pool to `index.db`.
  2. Call `index::get_path(pool, uuid)` which executes the `SELECT` query and returns the path.
  3. Read the file content at the retrieved path.

- **`aethel new --type <type> ...`**
  1. Load the Schema Registry (using cache).
  2. ... (determine plugin_id and target path)
  3. Create the new artifact file on disk.
  4. Establish a connection pool to `index.db`.
  5. Execute an `INSERT` query to add the new artifact's `uuid` and relative path to the index.

- **`aethel doctor [--fix]`**
  This command remains a precise and transparent maintenance tool.
  1. **`--rebuild-index`:** A new flag to trigger the index rebuild logic.
  2. **Transparency & Atomic Commits:** The principles of printing changes before fixing and using discrete commits per file are maintained.

#### 7. Error Handling (`error.rs`)

The custom error enum is expanded for database-specific issues:

```rust
#[derive(Debug, thiserror::Error)]
pub enum AethelError {
    #[error("Configuration not found. Please run 'aethel init <path>'.")]
    ConfigNotFound,
    #[error("A circular dependency was detected in your schema extensions involving '{0}'.")]
    CircularSchemaDependency(String),
    #[error("Database error: {0}")]
    Sqlx(#[from] sqlx::Error),
    // ... other errors from previous SDD ...
}
```

#### 8. Synchronization Protocol (Idempotency Specification)

This protocol remains unchanged. The `.aethel/` directory is **not** synced via Git. A `doctor --rebuild-index` run after a `git pull` that includes many new files created on another machine is a recommended workflow to bring the local index up to date.

#### 9. Testing Strategy

- **Unit Tests:** Will cover pure logic like schema inheritance resolution.
- **Integration Tests:** The test setup for each test will create a temporary directory and an independent, temporary SQLite database file (`.aethel/index.db`). This ensures tests are hermetic and can run in parallel. For performance, tests can use an in-memory SQLite database if `sqlx`'s test utilities support it easily.

