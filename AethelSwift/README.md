# AethelSwift

Swift implementation of Aethel-Core, providing 100% compatibility with the Rust implementation for iOS and macOS applications.

## Overview

AethelSwift implements the complete Aethel protocol in Swift, maintaining identical behavior to the Rust implementation. The library is designed for iOS and macOS applications that need to work with Aethel document vaults.

## Architecture

- **AethelCore**: L0 core library with pure Swift implementation
- **AethelCLI**: L1 command-line interface (compatible with Rust CLI)

## Requirements

- Swift 6.0+
- macOS 13.0+ / iOS 16.0+

## Building

```bash
# Build the library and CLI
swift build

# Build in release mode
swift build -c release

# Run tests
swift test

# Format code
make format

# Check formatting
make format-check
```

## Usage

### As a Library

```swift
import AethelCore

// Initialize a vault
try Vault.initialize(at: "/path/to/vault")
let vault = try Vault(at: "/path/to/vault")

// Create a document
let patch = Patch(mode: .create, frontMatter: ["title": "My Document"], body: "Content")
let result = try vault.applyPatch(patch)

// Read a document
let doc = try vault.readDoc(uuid: result.uuid)
print(doc.toMarkdown())
```

### Command Line Interface

```bash
# Initialize vault
.build/debug/aethel init /path/to/vault

# Write document
echo '{"mode": "create", "frontMatter": {"title": "Test"}, "body": "Content"}' | \
  .build/debug/aethel write doc --json - --vault-root /path/to/vault

# Read document
.build/debug/aethel read doc <uuid> --vault-root /path/to/vault
```

## Compatibility

AethelSwift is designed to be 100% compatible with the Rust implementation:

- Identical JSON output formatting
- Same error codes and messages
- Compatible file system layout
- Same YAML front-matter handling
- Identical golden test results

## Testing

The implementation includes:

- **Unit Tests**: Test individual components
- **Integration Tests**: Test end-to-end vault operations
- **Golden Tests**: Ensure compatibility with Rust implementation

Run all tests:

```bash
swift test
```

## Development

### Code Formatting

The project uses `swift-format` for consistent code formatting:

```bash
# Format all code
make format

# Check formatting
make format-check
```

### Project Structure

```
AethelSwift/
├── Package.swift
├── Sources/
│   ├── AethelCore/           # Core library
│   └── AethelCLI/            # CLI binary
├── Tests/
│   ├── AethelCoreTests/      # Unit tests
│   └── GoldenTests/          # Golden test harness
├── BuildTools/               # swift-format tooling
└── scripts/                  # Build scripts
```

## License

Same as the main Aethel project.