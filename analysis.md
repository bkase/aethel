## Analysis Summary

Based on my analysis of the Aethel codebase, here's what I found:

### 1. **Where the `new` command is defined (CLI structure)**
- **File**: `/Users/bkase/Documents/aethel/todos/worktrees/2025-07-19-21-15-41-add-body-argument-to-new-command/src/cli.rs`
- **Lines**: 19-32
- The command is defined as a variant of the `Commands` enum using clap's derive macros

### 2. **How the `new` command currently works**
The command flow is:
1. User invokes `aethel new --type <type> [--title <title>] [--field key=value]...`
2. Main parses CLI args (src/main.rs:26-32)
3. Calls `commands::new::execute()` with the parsed arguments
4. The execute function:
   - Loads config and vault path
   - Loads the plugin registry
   - Creates a new artifact with empty content
   - Writes it to disk
   - Updates the SQLite index
   - Prints the UUID

### 3. **Current arguments accepted**
- **`--type` / `-t`**: Required - Type of artifact to create (e.g., "core_note/note")
- **`--title`**: Optional - Title for the artifact
- **`--field` / `-f`**: Optional, repeatable - Additional fields as key=value pairs

### 4. **How artifact creation happens**
- **File**: `/Users/bkase/Documents/aethel/todos/worktrees/2025-07-19-21-15-41-add-body-argument-to-new-command/src/commands/new.rs`
- **Lines**: 58-61 - Creates an `Artifact` with empty content
- **Line**: 74 - Calls `write_artifact()` to save to disk
- **File**: `/Users/bkase/Documents/aethel/todos/worktrees/2025-07-19-21-15-41-add-body-argument-to-new-command/src/store.rs`
- **Lines**: 56-59 - `serialize_artifact()` formats as YAML frontmatter + content
- **Lines**: 26-37 - `write_artifact()` writes to disk

### 5. **Where to add the new --body argument**

To add a `--body` argument, changes are needed in:

1. **CLI Definition** (`src/cli.rs`):
   - Add a new field to the `New` command variant (after line 31):
   ```rust
   /// Body content for the artifact
   #[arg(long)]
   body: Option<String>,
   ```

2. **Main Command Handler** (`src/main.rs`):
   - Update the pattern match to include body (line 26-32):
   ```rust
   Commands::New {
       r#type,
       title,
       fields,
       body,
   } => {
       commands::new::execute(&r#type, title.as_deref(), &fields, body.as_deref()).await?;
   }
   ```

3. **Execute Function** (`src/commands/new.rs`):
   - Update function signature (line 12-16) to accept `body: Option<&str>`
   - Update artifact creation (line 58-61) to use the body instead of empty string:
   ```rust
   let artifact = Artifact {
       frontmatter,
       content: body.unwrap_or("").to_string(),
   };
   ```

The key insight is that artifacts are currently created with empty content (`String::new()` on line 60), and the `--body` argument would simply provide initial content instead of requiring a subsequent `grow` command.