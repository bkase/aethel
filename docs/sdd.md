# A4 (Rust) Engineering Design Doc

## 0) Scope

Build:

1. **`a4-core`** Rust library: vault resolution, date math, anchors, daily creation from template/blank, append-only block insertion, Git sync (library-backed).
2. **`a4`** CLI binary on top of `a4-core`.

Targets: macOS, Linux, Windows. No external Git subprocesses; use a Rust Git library.

Out of scope (v1): stitching/collation, advanced merge/rebase. (We’ll error gracefully on non-FF sync divergence.)

---

## 1) Git Backend Choice (no subprocesses)

### Recommended: `gix` (gitoxide)

- **Pure Rust**, easy to statically link, no libgit2 C dependency.
- Supports clone/fetch/push, refs, commits, object DB, status/index operations, and fast-forward updates.
- Rebase/three-way merges are still evolving—so v1 implements **fetch + fast-forward or error**. For divergent histories we return a precise diagnostic and recommend manual reconcile or a future “replay” strategy.

### Alternative: `git2` (libgit2)

- Mature surface area (including merge/rebase), but **C dependency** (libgit2). Static linking is possible but more finicky (platform-specific build config).
- We can keep a **Cargo feature** to switch backends:

```toml
[features]
git-gix = ["dep:gix"]
git-libgit2 = ["dep:git2"]
default = ["git-gix"]
```

**Decision:** Default to **`gix`** for portability and static builds. Phase-2 can add a rebase path behind `git-libgit2` if needed.

---

## 2) CLI Surface (from protocol)

We implement the **trimmed set**:

- `a4 today` — resolve/create today’s note (template or blank).
- `a4 append --heading <H> --anchor <tok> (--file <path> | --today) [--text <S> | --stdin]` — append anchored block; create **H2** heading if missing; append-only.
- `a4 sync [--message <m>] [--remote <name>] [--branch <name>] [--ff-only]` — library-backed fetch/commit/push; **fast-forward only** (error on divergence).

(Commands and behaviors are aligned with your protocol’s normative CLI section. )

**Global flags**

- `--vault <path>` (override vault root)
- `-v/--verbose` (info/debug/trace)

---

## 3) Vault Resolution (final)

Resolution order:

1. `--vault <path>`
2. `A4_VAULT_DIR` env var
3. If CWD or its ancestors contain `/.a4/` → that directory is the vault root
4. **Fallback:** `$HOME/Documents/a4-core` **(new requirement)**

On success, the path is **canonicalized**; on failure, return an error listing attempted strategies.

---

## 4) Behavior Details (as per protocol, with your updates)

### 4.1 `a4 today`

- Compute UTC day for filename: `capture/YYYY/YYYY-MM/YYYY-MM-DD.md` (UTC in filename per spec intent).
- If **template** exists at `routines/templates/daily.md`:
  - Read template bytes → write file with those bytes, unless file already exists.

- If no template: create **blank** file (touch) with trailing newline.
- Always **mkdir -p** parent dirs.
- Print absolute path to stdout.
  (“Resolve path to today’s daily note; create from template if absent”—and now also allow “blank if template missing.” )

### 4.2 `a4 append`

- **Heading policy:** create missing heading as **H2** (`## {heading}`) followed by a blank line.
  - Respect an existing H1 at top if present; do not alter it.

- **Anchor token grammar** (from protocol):
  `^<prefix>-<HHMM>(__suffix)?` where:
  - `prefix`: `[a-z][a-z0-9-]{1,24}`
  - `HHMM`: exactly 4 digits (00–23, 00–59)
  - optional suffix: `__{device}` (stored as the `suffix` without the leading `__` in the parsed struct)

- **Append-only semantics**:
  - Never reorder existing content.

  - Ensure exactly one blank line before writing the anchor line if EOF isn’t blank.

  - Write block as:

    ```
    \n^<token>\n<content>\n
    ```

  - If the specified heading is missing, **create `## {heading}\n\n` at EOF**, then append the block.

  - Do **not** coalesce duplicates (collation is a future tool).

- Validates anchor token; rejects malformed tokens with a descriptive error; never mutates prior bytes beyond appending.
  (“Append block under anchor; create heading if missing; never reorder/rewrite”—per protocol. )

### 4.3 `a4 sync` (no subprocess)

- **Algorithm (gix)**:
  1. Detect repo root from vault; if none, return a helpful error (“Initialize Git: `git init` and set remote, or run `a4 sync --init` (future)”).
  2. Stage changes (index add-all).
  3. If index differs from HEAD, create commit with message (default `a4: sync`).
  4. **Fetch** from `--remote` (default `origin`), the current branch (or `--branch`).
  5. Determine merge base; if **fast-forward possible**, update local branch ref and working tree to fetched tip.
     - If local has uncommitted changes at this step, we already committed before fetch, so only FF remains.

  6. If **divergence** (non-FF): **return non-zero** with a clean diagnostic:
     - Show short SHAs of local HEAD and remote, and suggested next steps (e.g., “resolve divergence via manual rebase/merge; Phase-2 will support auto reapply”).

  7. **Push** local branch to remote.

- Flags:
  - `--message <m>` commit message override.
  - `--remote <name>` default `origin`.
  - `--branch <name>` if omitted, use current HEAD symbolic ref.
  - `--ff-only` (default true) — explicit to document behavior.

- **Note:** Your protocol exemplifies `pull --rebase` in guidance. We’re delivering **FF-only** with an explicit, actionable error if divergent, which is safe and fully library-backed today. (The CLI section in your doc leaves the exact internals open; it only states “pull-rebase, add all, commit, push” as a helper. We’ll match the **spirit** safely without subprocess rebase for v1. )

---

## 5) Crate Layout

```
a4/
├─ Cargo.toml                      # workspace
├─ Makefile                        # build/lint/test/dev (see §9)
├─ .github/workflows/ci.yml
├─ crates/
│  ├─ a4-core/
│  │  ├─ src/
│  │  │  ├─ lib.rs
│  │  │  ├─ vault.rs              # vault resolution + today path
│  │  │  ├─ date.rs               # UTC day, local HHMM, ISO week
│  │  │  ├─ anchors.rs            # parse/validate anchor tokens
│  │  │  ├─ headings.rs           # ensure H2 heading
│  │  │  ├─ notes.rs              # read/write, front-matter tolerant
│  │  │  ├─ append.rs             # append-only block insertion
│  │  │  ├─ git_backend.rs        # trait + gix implementation
│  │  │  ├─ error.rs              # thiserror error types
│  │  │  └─ util.rs               # fs helpers, path safety
│  │  ├─ tests/                   # integration tests with temp dirs
│  │  └─ Cargo.toml
│  └─ a4-cli/
│     ├─ src/main.rs
│     ├─ src/cli.rs               # clap commands & flags
│     ├─ src/logging.rs           # tracing subscriber
│     ├─ src/env.rs               # vault resolution glue
│     └─ Cargo.toml
└─ README.md
```

---

## 6) Dependencies

**Library (`a4-core`)**

- `thiserror` — error modeling.
- `regex` — anchors/heading detect.
- `time` + `time-tz` — UTC day and local `HHMM`.
- `gix` — Git backend (feature-gated; default).
  - Optional `git2` behind `git-libgit2` feature.

- `serde`, `serde_yaml` (optional) — front matter pass-through if we later need to read/augment; **v1 only preserves bytes**.
- `fs-err` (optional) — better error messages on file ops.

**CLI (`a4-cli`)**

- `clap` v4 (derive).
- `anyhow` — top-level error boundary.
- `tracing`, `tracing-subscriber`.

Dev:

- `tempfile` — temp dirs in tests.
- `insta` (optional) — snapshot tests on append semantics.
- `pretty_assertions` (optional) — diffs.

---

## 7) Public Library API (summary)

```rust
// lib.rs
pub mod vault;
pub mod date;
pub mod anchors;
pub mod headings;
pub mod notes;
pub mod append;
pub mod git_backend;
pub mod error;

pub use vault::{Vault, VaultOpts, VaultRoot};
pub use date::{UtcDay, IsoWeek, LocalClock};
pub use anchors::AnchorToken;
pub use append::{AppendOptions, append_block};
```

### 7.1 Vault

```rust
pub struct Vault {
    root: PathBuf, // canonical
}

pub enum VaultRoot {
    FromCli(PathBuf),
    FromEnv(PathBuf),
    FromMarker(PathBuf),   // found ".a4" in ancestor
    Default(PathBuf),      // $HOME/Documents/a4-core
}

pub struct VaultOpts { pub ensure_exists: bool }

impl Vault {
    pub fn open<P: AsRef<Path>>(path: P, opts: VaultOpts) -> Result<Self, A4Error>;
    pub fn resolve_default() -> Result<(Self, VaultRoot), A4Error>; // applies full search order
    pub fn capture_day_path(&self, utc_day: UtcDay) -> PathBuf;     // capture/YYYY/YYYY-MM/YYYY-MM-DD.md
    pub fn ensure_parents(&self, path: &Path) -> Result<(), A4Error>;
    pub fn root(&self) -> &Path;
}
```

### 7.2 Date/Time

```rust
pub struct UtcDay { pub year: i32, pub month: u8, pub day: u8 }
pub struct IsoWeek { pub year: i32, pub week: u8 }

pub trait LocalClock {
    fn now_local_hhmm() -> String;      // "HHMM"
    fn today_utc() -> UtcDay;           // from current instant
    fn iso_week(utc: &UtcDay) -> IsoWeek;
}
```

### 7.3 Anchors

```rust
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AnchorToken {
    pub prefix: String,             // [a-z][a-z0-9-]{1,24}
    pub hhmm: String,               // 4 digits
    pub suffix: Option<String>,     // without leading "__"
}

impl AnchorToken {
    pub fn parse(token: &str) -> Result<Self, A4Error>; // parse "focus-0930" or "focus-0930__iphone"
    pub fn to_marker(&self) -> String;                  // "^focus-0930__iphone"
}
```

### 7.4 Headings

```rust
/// Ensure an H2 "## {heading}" exists in `content`, returning the modified content
/// and a bool 'created'.
pub fn ensure_h2_heading(content: &str, heading: &str) -> (String, bool);

// Rules:
// - If "## {heading}" exists (case-insensitive compare on heading text), no-op.
// - If only H1 "# {heading}" exists, do not change it; still create "## {heading}".
// - If none exist, append "\n## {heading}\n\n" to EOF (ensure exactly one trailing blank line).
```

### 7.5 Notes

```rust
pub struct Note {
    pub path: PathBuf,
    pub body: String,                  // full file contents
    pub front_matter: Option<String>,  // raw '--- ... ---' if present
}

pub fn read_note(path: &Path) -> Result<Note, A4Error>;
pub fn write_note(path: &Path, body: &str) -> Result<(), A4Error>;

// Front-matter helpers (v1: preserve bytes, don't mutate):
pub fn split_front_matter(raw: &str) -> (Option<&str>, &str);
pub fn join_front_matter(fm: Option<&str>, body: &str) -> String;
```

### 7.6 Append

```rust
pub struct AppendOptions<'a> {
    pub heading: &'a str,        // user provided heading name
    pub anchor: AnchorToken,
    pub content: &'a str,        // stdin or --text
}

pub fn append_block(vault: &Vault, file: &Path, opts: AppendOptions) -> Result<(), A4Error>;
```

**Algorithm**

- Read file (or start from empty string).
- Ensure **H2 heading** with `ensure_h2_heading`.
- If last line not blank, add exactly one newline.
- Append: `\n^<anchor>\n<content>\n`
- Write atomically (temp file + rename).
- Never mutate prior content; never reorder.

### 7.7 Git Backend

Define a trait and implement with `gix`:

```rust
pub trait GitBackend {
    fn open(cwd: &Path) -> Result<Self, A4Error> where Self: Sized;
    fn stage_all(&mut self) -> Result<(), A4Error>;
    fn commit_if_needed(&mut self, message: &str) -> Result<bool, A4Error>;
    fn fetch(&mut self, remote: &str, branch: Option<&str>) -> Result<(), A4Error>;
    fn fast_forward_current_branch(&mut self, remote_ref: &str) -> Result<bool, A4Error>; // Ok(true) if FF applied
    fn push(&mut self, remote: &str, branch: Option<&str>) -> Result<(), A4Error>;
    fn head_branch(&self) -> Result<String, A4Error>;
    fn diverged(&self, remote_ref: &str) -> Result<bool, A4Error>;
}
```

- **`fast_forward_current_branch`**: Resolve `refs/remotes/<remote>/<branch>` and update `refs/heads/<branch>` if FF calc indicates safe; update worktree as needed.
- **Divergence**: If not FF, return `true` from `diverged()` so CLI prints actionable error.
- Phase-2 can add reapply/cherry-pick or rebase behind a feature.

---

## 8) CLI Wiring

### 8.1 Clap Definition

```
a4 [--vault PATH] [-v...]

SUBCOMMANDS
  today
  append --heading <HEADING> --anchor <TOKEN> (--file <PATH> | --today) [--text <S> | --stdin]
  sync [--message <MSG>] [--remote <NAME>] [--branch <NAME>] [--ff-only]
```

- `append`: require one of `--text` or `--stdin` (v1); later we can open `$EDITOR`.
- `--today` targets the resolved daily path.
- Exit codes: non-zero on validation errors, IO, or sync divergence.

### 8.2 Logging

- `-v` → debug, `-vv` → trace (via `tracing_subscriber::fmt()`).

---

## 9) Makefile & CI

### 9.1 `Makefile`

```make
.PHONY: all fmt lint test build run install clean

all: fmt lint test build

fmt:
 cargo fmt --all

lint:
 cargo clippy --all-targets -- -D warnings

test:
 cargo test --all

build:
 cargo build --workspace --release

run:
 cargo run -p a4-cli -- $(ARGS)

install:
 cargo install --path crates/a4-cli

clean:
 cargo clean
```

Usage: `make`, `make run ARGS="today"`, etc.

### 9.2 GitHub Actions (`.github/workflows/ci.yml`)

- Jobs: ubuntu + macos.
- Steps: checkout → toolchain (stable) → cache cargo → `make fmt lint test`.

---

## 10) Tests

### Unit

- **Anchors**: valid/invalid (`focus-0930`, `jrnl-0812__iphone`, reject `FOCUS-0930`, `2460`, etc.).
- **Headings**:
  - Insert H2 when missing.
  - Do not duplicate if present (case-insensitive).
  - Preserve an existing H1.

- **Front-matter splitter**: preserve raw bytes; handle no FM.

### Integration (temp dirs)

- **today_blank_when_no_template**: no `routines/templates/daily.md` → creates empty file; prints absolute path.
- **today_uses_template**: with template, file equals template bytes.
- **append_adds_h2_if_missing**: empty file → after append, contains `## Heading` + anchor + content.
- **append_is_append_only**: two appends preserve order; exactly one blank line before each anchor.
- **sync_ff_only**:
  - Clean repo: commit_if_needed returns false; push still OK.
  - With remote fast-forward available: apply and push.
  - With divergence: return non-zero; message explains local vs remote tips clearly.

---

## 11) Security & Safety

- **Path safety**: canonicalize + ensure all target paths stay **under vault root**; reject traversal.
- **Atomic writes**: write to temp + `rename`.
- **UTF-8**: validate before write; error on invalid sequences.
- **Line endings**: write `\n` normalized; preserve existing FM bytes verbatim.
- **Race safety**: repository operations guarded; we don’t implement file locks in v1 (single-writer expected on device), but future `.a4/lock` is possible.

---

## 12) Acceptance Criteria

- **today**
  - Creates `capture/YYYY/YYYY-MM/YYYY-MM-DD.md` (UTC filename).
  - Uses template if present; otherwise blank file.
  - Prints absolute path.

- **append**
  - Validates anchor; creates **H2** heading if missing; appends block without mutating earlier bytes.
  - Never reorders; ensures one blank line before anchor; trailing newline at EOF.

- **sync**
  - Stages, commits (if needed), fetches, **fast-forwards** when possible, pushes.
  - On divergence: exit non-zero with diagnostic; no repository corruption.

- **Vault resolution**
  - Honors `--vault`, then `A4_VAULT_DIR`, then `.a4` marker, then **`$HOME/Documents/a4-core`** fallback.

All align with the protocol’s CLI intent and append-only semantics. &#x20;

---

## 13) Phase-2 Backlog (post-v1)

- Optional **rebase/reapply** on divergence (behind `git-libgit2` or advanced `gix` merge once stabilized).
- `stitch` (render transcludes) and `collate` (device block coalescer).
- `$EDITOR` fallback for `append` when neither `--text` nor `--stdin` provided.
- Config file `.a4/config.toml` (default headings, date policy).
- Asset helpers (submodule init/update, LFS helpers).
- Windows CRLF heuristics (preserve or normalize based on existing file).

---

## 14) Developer Notes

- MSRV: 1.74+
- Keep modules small and heavily unit-tested.
- Document invariants in code (append-only guarantee, H2 policy, UTC-filename rule).
- Prefer explicit errors (`thiserror` in lib; `anyhow` at CLI boundary).
- Avoid panics in library; CLI can pretty-print rich errors.
