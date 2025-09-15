Below is a clean, engineer-ready **Software Design Document (SDD)** for the **Swift A4 Core** library only—**no CLI**, **no repo/vault creation**, **no git operations**. It assumes an **existing A4 vault** on disk (created by your Rust toolchain). The API is designed for apps (iOS/macOS/Linux) to **resolve paths, append anchored blocks, and create Markdown files** inside the vault—**bit-for-bit identical** to the Rust implementation’s observable file behavior.

---

# A4CoreSwift — Software Design Document (Core-only)

**Status:** Implementable
**Targets:** macOS 13+, iOS 16+, Linux (Swift 6)
**License:** Same as Rust A4
**Goal:** Provide a Swift library whose **outputs on disk are byte-for-byte identical** to the Rust A4 core for overlapping functionality.

## 0) Scope

In-scope (v1 Swift Core):

* **Vault resolution** (existing vault only): `--vault` equivalent, `A4_VAULT_DIR`, `.a4` ancestor marker, fallback `$HOME/Documents/a4-core`. No creation; error if missing.
* **Path utilities:**

  * Compute **today’s daily note path (UTC filename rule)** for apps that need it.
  * Resolve arbitrary relative paths inside the vault (with path safety).
* **Markdown operations:**

  * **Append anchored block** under a given **H2** heading (create the H2 if missing).
  * **Create a Markdown file** at a given relative path (from provided bytes or empty).
* **I/O discipline:** atomic write (temp+rename), single `\n` line endings, preserve front matter bytes if present, **never reorder** existing content.
* **Anchors:** parse/validate grammar `^<prefix>-<HHMM>(__suffix)?`.

Out-of-scope (v1 Swift Core):

* Any **CLI**.
* **Vault/repo initialization** or **git** operations.
* Stitching/collation or LLM/AI features.

---

## 1) Parity Contract (with Rust Core)

The Swift core must match the Rust core **bit-for-bit** for the following observable effects:

1. **Daily path rule:** `capture/YYYY/YYYY-MM/YYYY-MM-DD.md` using **UTC** date (filename only).
2. **Anchor grammar:** `^<prefix>-<HHMM>(__suffix)?` (`prefix=[a-z][a-z0-9-]{1,24}`, `HHMM` 4 digits, local time).
3. **Heading policy:** reserve **H1** for title if present; create **H2** (`## {Heading}`) when missing, followed by exactly **one blank line**.
4. **Append**: append-only; ensure exactly **one** blank line before the new `^anchor` line; always end the file with a newline.
5. **Front matter**: if a note starts with front matter (`---\n ... \n---\n`), **preserve its bytes verbatim**.
6. **Encoding**: UTF-8 only; fail clearly on invalid inputs.
7. **Paths**: disallow writes outside the vault root (canonicalized prefix check).
8. **Template usage**: the Swift core does **not** auto-create today from templates; if an app wants to create a file, it provides the bytes. (This differs from Rust “today command”, which is intentionally out of scope here.)

---

## 2) Package Layout (SwiftPM)

```
A4Swift/
├─ Package.swift
├─ Sources/
│  └─ A4CoreSwift/
│     ├─ Vault/       # vault resolution & path safety
│     ├─ Dates/       # UTC daily filename, local HHMM
│     ├─ Anchors/     # token parsing/validation
│     ├─ Notes/       # front-matter split/join, atomic I/O
│     ├─ Headings/    # ensure H2 insertion
│     ├─ Append/      # append-only block writer
│     ├─ Errors/      # error types
│     └─ Util/        # newline helpers, fs utils
└─ Tests/
   ├─ A4CoreSwiftTests/        # unit+integration tests
   └─ A4GoldenParityTests/     # byte-for-byte parity fixtures vs Rust outputs
```

---

## 3) Dependencies

* **Swift Argument Parser**: **not needed** (no CLI).
* **swift-format**: formatting (via Make).
* **XCTest**: tests.
* No YAML parser needed (we preserve front-matter bytes).
* No git/libgit2 needed (core only).

---

## 4) Public API

> All APIs are synchronous and throw `A4Error`. Add async variants later if needed.

### 4.1 Errors

```swift
public enum A4Error: Error, CustomStringConvertible {
  case vaultNotFound(String)     // "No vault at: …"
  case invalidVault(String)      // path exists but not directory / unreadable
  case invalidAnchor(String)     // details included
  case io(String)                // underlying fs error message
  case encoding(String)          // invalid UTF-8 or similar
  case pathEscape(String)        // attempted write outside vault

  public var description: String { /* stable messages */ }
}
```

### 4.2 Vault

```swift
public struct Vault {
  public let root: URL

  /// Throws if root does not exist or is not a directory (no creation).
  public init(root: URL) throws

  /// Resolve vault location by the standard search order.
  /// - Parameters:
  ///   - cliPath: explicit path an app may pass (highest precedence)
  ///   - env: environment dictionary to check A4_VAULT_DIR
  ///   - cwd: current working directory for ancestor .a4 search
  /// - Returns: (vault, origin)
  public static func resolve(
    cliPath: URL?, env: [String:String], cwd: URL
  ) throws -> (vault: Vault, origin: VaultOrigin)

  public enum VaultOrigin { case cli, env, marker, fallback }

  /// Safe join: returns an absolute URL for a relative path,
  /// throwing if canonicalized path would escape the vault root.
  public func resolveRelative(_ rel: String) throws -> URL
}
```

**Resolution order (must match Rust):**

1. `cliPath` if provided.
2. `env["A4_VAULT_DIR"]`.
3. Walk up from `cwd` to find a directory containing `/.a4/` (marker).
4. Fallback: `$HOME/Documents/a4-core`.
   Thrown errors should indicate which strategies were attempted.

### 4.3 Dates

```swift
public struct UtcDay { public let year: Int, month: Int, day: Int }

public protocol DateProvider {
  func now() -> Date
}
public struct SystemDateProvider: DateProvider {
  public init() {}
  public func now() -> Date { Date() }
}

public enum Dates {
  /// Convert a Date to UtcDay.
  public static func utcDay(from date: Date) -> UtcDay

  /// Build daily path components from a UtcDay:
  ///   ("YYYY", "YYYY-MM", "YYYY-MM-DD.md")
  public static func dailyPathComponents(for day: UtcDay) -> (String, String, String)

  /// Local HHMM time string (zero-padded 4 digits).
  public static func localHHMM(from date: Date) -> String
}
```

> The **daily path computation is provided**, but **no file is created**. Apps can call `vault.resolveRelative("capture/\(y)/\(y)-\(m)/\(y)-\(m)-\(d).md")` to open/create as needed.

### 4.4 Anchors

```swift
public struct AnchorToken: Equatable, Sendable {
  public let prefix: String   // [a-z][a-z0-9-]{1,24}
  public let hhmm: String     // 4 digits "0930"
  public let suffix: String?  // device id, no leading "__"

  public init(parse token: String) throws  // e.g., "focus-0930__iphone"
  public func marker() -> String           // e.g., "^focus-0930__iphone"
}
```

Validation rules enforced; informative error messages on failure.

### 4.5 Front Matter & Notes

```swift
public enum FrontMatterSplit {
  case none(body: Data)
  case present(header: Data, body: Data) // raw bytes between '---' fences

  public var header: Data? { ... }
  public var body: Data { ... }
}

public enum Notes {
  /// Non-destructive split; if no FM, returns .none
  public static func splitFrontMatter(_ bytes: Data) -> FrontMatterSplit

  /// Non-destructive join; if 'header' is nil, returns 'body'.
  public static func joinFrontMatter(header: Data?, body: Data) -> Data
}
```

* We **do not parse** YAML; bytes are preserved exactly.

### 4.6 Headings

```swift
public enum Headings {
  /// Ensure a level-2 heading "## {heading}" exists in 'textBytes'.
  /// If missing, append exactly:
  ///   "\n## {heading}\n\n"
  /// Returns modified bytes. Does not alter an existing H1 or H2 with the same title.
  public static func ensureH2(textBytes: Data, heading: String) throws -> Data
}
```

* Matching is case-insensitive on the heading text for H2.
* If an H2 of the same title already exists, do nothing.
* If only H1 exists, leave it; still create H2.

### 4.7 Append (append-only block)

```swift
public struct AppendOptions {
  public let heading: String        // e.g., "Journal"
  public let anchor: AnchorToken    // validated token
  public let content: Data          // UTF-8 payload (no trailing newline required)

  public init(heading: String, anchor: AnchorToken, content: Data)
}

public enum Append {
  /// Append an anchored block to 'targetFile' located under 'vault'.
  ///
  /// Behavior:
  /// - Reads file (if missing, starts from empty).
  /// - Ensures H2 "## heading" exists (appends "\n## heading\n\n" if absent).
  /// - Ensures exactly ONE blank line before "^anchor" (newline discipline).
  /// - Appends block as:
  ///     "\n^<token>\n<content>\n"
  /// - Writes atomically (temp+rename), never reorders prior bytes.
  ///
  /// Throws on invalid anchor, I/O errors, path escaping, or invalid UTF-8 'content'.
  public static func appendBlock(
    vault: Vault, targetFile: URL, opts: AppendOptions
  ) throws
}
```

**Newline discipline (bit-for-bit):**

* Normalize to `\n` endings on write.
* If the existing file does not end with `\n`, add exactly one.
* Before writing, add exactly one leading `\n` so there is one blank line between previous content and `^anchor`.
* Always ensure the final byte of the file is `\n`.

### 4.8 Create Markdown File (explicit)

```swift
public enum CreateMode { case createNew, createIfMissing, overwrite }

public enum Files {
  /// Create or write a Markdown file safely inside the vault (atomic write).
  /// - Ensures parent directories exist.
  /// - Enforces path stays within vault.
  /// - Normalizes trailing newline.
  /// - Returns an error for createNew if file already exists.
  public static func writeMarkdown(
    vault: Vault,
    at relativePath: String,
    bytes: Data,
    mode: CreateMode
  ) throws
}
```

* This covers “add a markdown file somewhere in the vault” with strict semantics.
* For blank files: pass `Data()`; the function will still ensure a trailing newline.

---

## 5) Implementation Details

### 5.1 Atomic Writes

* Write to `.<filename>.tmp` in the same directory, `fsync` (platform permitting), then `rename` to target.
* Create parent directories if missing.
* Avoid partial writes visible to other processes.

### 5.2 Path Safety

* `vault.resolveRelative(rel)`:

  * Disallow absolute inputs.
  * Reject `..` or symlink escapes by canonicalizing target and verifying it has the vault root as a prefix.
  * Return a URL guaranteed to be under `vault.root`.

### 5.3 Encoding & Line Endings

* Inputs are UTF-8. Validate `opts.content` can be decoded/encoded without loss; otherwise `A4Error.encoding`.
* All writes use `\n`.
* Ensure a trailing newline at EOF.

### 5.4 Front Matter

* Scanner looks for exactly:

  * Start: `---\n`
  * End:   `\n---\n` (first such fence *after* start).
* Everything between (including the end fence) is `header`. Do not alter.

---

## 6) Tests

### 6.1 Unit Tests

* **Anchors**: accept `focus-0930`, `jrnl-0812__iphone`; reject `FOCUS-0930`, `2500`, `bad__sfx__more`, etc.
* **Headings**:

  * Insert missing H2 → exact bytes `\n## Heading\n\n`.
  * No duplication if H2 exists.
  * Do not touch H1.
* **Front matter**: split/join preserves bytes exactly (single/multi-line).
* **Path safety**: reject `../../escape.md` and symlink escapings.

### 6.2 Integration Tests

* **Append on empty file** → creates H2 + block with exact newline framing.
* **Append when H2 exists** → only the block is added; no extra whitespace.
* **Append twice** → order preserved; exactly one blank line between blocks; final newline ensures.
* **Create markdown** (`createNew`, `createIfMissing`, `overwrite`) semantics.
* **Vault resolution**: precedence check—cli > env > marker > fallback.

### 6.3 Golden Parity Tests

* Provide fixtures generated by the **Rust** core operations (checked into `Tests/Fixtures/.../expected/`).
* Each Swift test runs the same operation over a fresh temp copy of `initial/` and compares the full tree vs `expected/` **byte-for-byte** (excluding `.git/` and OS detritus).
* Use an injectable `DateProvider` for deterministic timestamps (`HHMM`) and daily filenames.

---

## 7) Build, Lint, CI

### 7.1 Makefile

```make
.PHONY: all fmt lint test build clean

all: fmt lint test build

fmt:
	./scripts/run-swift-format.sh --in-place --recursive ./Sources ./Tests

lint:
	@echo "lint ok"  # add swiftlint if desired

test:
	swift test

build:
	swift build -c release

clean:
	swift package clean
```

### 7.2 CI (GitHub Actions)

* macOS + Ubuntu runners.
* Steps: checkout → set up Swift 6 → `make fmt lint test`.

---

## 8) Acceptance Criteria

* **Vault resolution** matches precedence and errors out if the resolved path doesn’t exist or isn’t a directory.
* **Append** produces exactly:

  * H2 insertion `\n## {Heading}\n\n` when missing.
  * New block as `\n^token\ncontent\n`.
  * Single blank line before every new `^token`.
  * Final newline at EOF.
  * No reordering of prior bytes; front matter preserved.
* **Create Markdown** adheres to `CreateMode` semantics; writes are atomic; path stays within vault.
* **Parity tests** all pass vs Rust golden fixtures.

---

## 9) Example Usage (Library)

```swift
import A4CoreSwift

let (vault, _) = try Vault.resolve(
  cliPath: nil,
  env: ProcessInfo.processInfo.environment,
  cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
)

// 1) Resolve today's UTC file path (no creation)
let now = Date()
let day = Dates.utcDay(from: now)
let (y, ym, file) = Dates.dailyPathComponents(for: day)
let todayURL = try vault.resolveRelative("capture/\(y)/\(ym)/\(file)")

// 2) Append a journal block
let token = try AnchorToken(parse: "jrnl-\(Dates.localHHMM(from: now))")
let content = Data("Quick thought from iOS…".utf8)
try Append.appendBlock(
  vault: vault,
  targetFile: todayURL,
  opts: .init(heading: "Journal", anchor: token, content: content)
)

// 3) Create a new source note
let md = Data("# My Note\n\nSome content.\n".utf8)
try Files.writeMarkdown(
  vault: vault,
  at: "sources/articles/my-note.md",
  bytes: md,
  mode: .createIfMissing
)
```

---

## 10) Timeline (suggested)

* **Week 1:** Vault resolution, Dates, Anchors (units), Notes (FM split/join), Headings (units).
* **Week 2:** Append (integration), Files.createMarkdown, newline discipline edge cases.
* **Week 3:** Golden parity fixtures & tests, CI, polish, docs.

---

This SDD keeps the Swift core **lean** and **app-friendly** while preserving strict **byte-parity** with the Rust implementation for overlapping behaviors. If you later add `stitch`/`collate` to Rust Core, we can extend this Swift core the same way without introducing a CLI.
