# Swift Implementation Plan for Aethel-Core

## Overview

This document outlines the plan for implementing aethel-core in Swift, targeting iOS and macOS applications. The implementation will maintain 100% compatibility with the Rust implementation, ensuring identical golden test outputs.

## Architecture

### Swift Package Manager Structure

```
AethelSwift/
├── Package.swift
├── Sources/
│   ├── AethelCore/           # L0: Core library
│   │   ├── Models/
│   │   │   ├── Doc.swift
│   │   │   ├── Pack.swift
│   │   │   └── Patch.swift
│   │   ├── Vault/
│   │   │   ├── Vault.swift
│   │   │   └── Operations.swift
│   │   ├── Validation/
│   │   │   ├── JSONSchema.swift
│   │   │   └── Validator.swift
│   │   ├── FileSystem/
│   │   │   ├── AtomicWrite.swift
│   │   │   └── PathHelpers.swift
│   │   ├── Parser/
│   │   │   ├── YAMLFrontMatter.swift
│   │   │   └── MarkdownBody.swift
│   │   └── Error/
│   │       └── ProtocolErrors.swift
│   └── AethelCLI/             # L1: CLI binary
│       ├── main.swift
│       ├── Commands/
│       │   ├── Init.swift
│       │   ├── Write.swift
│       │   ├── Read.swift
│       │   ├── Check.swift
│       │   ├── ListPacks.swift
│       │   ├── AddPack.swift
│       │   └── RemovePack.swift
│       └── IO/
│           ├── JSONInput.swift
│           └── JSONOutput.swift
└── Tests/
    ├── AethelCoreTests/       # Unit tests
    │   ├── DocTests.swift
    │   ├── PackTests.swift
    │   ├── PatchTests.swift
    │   ├── VaultTests.swift
    │   └── ValidationTests.swift
    └── GoldenTests/           # Golden test harness
        ├── GoldenTestRunner.swift
        ├── TestCase.swift
        └── Helpers/
            ├── DirectoryComparison.swift
            └── OutputNormalization.swift
```

## Implementation Details

### Phase 1: Core Data Models and Operations

#### 1.1 Core Data Models

```swift
// Models/Doc.swift
import Foundation

public struct Doc: Codable, Sendable, Equatable {
    public let uuid: UUID
    public let frontMatter: [String: Any]  // Will use custom Codable implementation
    public let body: String
    
    // Custom encoding/decoding to handle YAML frontmatter
    public init(from markdown: String) throws { ... }
    public func toMarkdown() -> String { ... }
}

// Models/Pack.swift
public struct Pack: Codable, Sendable, Equatable {
    public let name: String
    public let types: [String: JSONSchema]
    public let templates: [String: Template]
    public let migrations: [Migration]
    
    public struct Template: Codable, Sendable, Equatable {
        public let frontMatter: [String: Any]?
        public let body: String?
    }
    
    public struct Migration: Codable, Sendable, Equatable {
        public let from: String
        public let to: String
        public let script: String
    }
}

// Models/Patch.swift
public struct Patch: Codable, Sendable, Equatable {
    public enum Mode: String, Codable, Sendable {
        case create
        case append
        case replace
        case merge
    }
    
    public let mode: Mode
    public let frontMatter: [String: Any]?
    public let body: String?
}
```

#### 1.2 YAML Front-Matter Parsing

Using Yams for YAML parsing:

```swift
// Parser/YAMLFrontMatter.swift
import Foundation
import Yams

public struct FrontMatterParser {
    private static let delimiter = "---\n"
    
    public static func parse(_ content: String) throws -> (frontMatter: [String: Any], body: String) {
        guard content.starts(with: delimiter) else {
            return ([:], content)
        }
        
        let contentAfterFirstDelimiter = String(content.dropFirst(delimiter.count))
        guard let endIndex = contentAfterFirstDelimiter.firstIndex(of: "\n---\n") else {
            throw AethelError.malformedFrontMatter
        }
        
        let yamlContent = String(contentAfterFirstDelimiter[..<endIndex])
        let bodyStart = contentAfterFirstDelimiter.index(endIndex, offsetBy: 5) // "\n---\n".count
        let body = String(contentAfterFirstDelimiter[bodyStart...])
        
        let frontMatter = try Yams.load(yaml: yamlContent) as? [String: Any] ?? [:]
        return (frontMatter, body)
    }
    
    public static func serialize(frontMatter: [String: Any], body: String) throws -> String {
        guard !frontMatter.isEmpty else {
            return body
        }
        
        let yamlString = try Yams.dump(object: frontMatter)
        return "---\n\(yamlString)---\n\(body)"
    }
}
```

#### 1.3 JSON Schema Validation

Port the Rust jsonschema validation logic:

```swift
// Validation/JSONSchema.swift
import Foundation

public struct JSONSchema: Codable, Sendable {
    public let schema: String // "$schema"
    public let type: JSONType?
    public let properties: [String: JSONSchema]?
    public let required: [String]?
    public let items: Box<JSONSchema>?
    public let additionalProperties: Either<Bool, Box<JSONSchema>>?
    // ... other JSON Schema properties
    
    public enum JSONType: String, Codable {
        case object, array, string, number, integer, boolean, null
    }
}

// Validation/Validator.swift
public struct JSONSchemaValidator {
    private let schema: JSONSchema
    
    public init(schema: JSONSchema) {
        self.schema = schema
    }
    
    public func validate(_ value: Any) throws {
        try validateValue(value, against: schema, at: JSONPointer.root)
    }
    
    private func validateValue(_ value: Any, against schema: JSONSchema, at pointer: JSONPointer) throws {
        // Port validation logic from Rust implementation
        // Ensure error codes match protocol specification
    }
}
```

#### 1.4 File System Operations

Atomic write implementation:

```swift
// FileSystem/AtomicWrite.swift
import Foundation

public struct AtomicFileWriter {
    public static func write(_ data: Data, to url: URL) throws {
        let tempURL = url.appendingPathExtension("tmp.\(UUID().uuidString)")
        
        do {
            try data.write(to: tempURL)
            
            // Use atomic move operation
            _ = try FileManager.default.replaceItem(
                at: url,
                withItemAt: tempURL,
                backupItemName: nil,
                options: []
            )
        } catch {
            // Clean up temp file on error
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }
    
    public static func write(_ string: String, to url: URL) throws {
        guard let data = string.data(using: .utf8) else {
            throw AethelError.encodingError
        }
        try write(data, to: url)
    }
}
```

#### 1.5 Protocol Error Handling

```swift
// Error/ProtocolErrors.swift
import Foundation

public enum AethelError: LocalizedError, Codable {
    // 400xx - Bad Request
    case malformedInput(code: Int = 40000, message: String)
    case malformedFrontMatter(code: Int = 40001, message: String)
    
    // 404xx - Not Found
    case docNotFound(code: Int = 40400, uuid: UUID)
    case packNotFound(code: Int = 40401, name: String)
    
    // 409xx - Conflict
    case docAlreadyExists(code: Int = 40900, uuid: UUID)
    case packAlreadyExists(code: Int = 40901, name: String)
    
    // 422xx - Validation
    case schemaValidationFailed(code: Int = 42200, details: String)
    case invalidPatchMode(code: Int = 42201, mode: String)
    
    // 500xx - System
    case ioError(code: Int = 50000, message: String)
    case encodingError(code: Int = 50001)
    
    public var errorCode: Int {
        switch self {
        case .malformedInput(let code, _): return code
        case .malformedFrontMatter(let code, _): return code
        case .docNotFound(let code, _): return code
        case .packNotFound(let code, _): return code
        case .docAlreadyExists(let code, _): return code
        case .packAlreadyExists(let code, _): return code
        case .schemaValidationFailed(let code, _): return code
        case .invalidPatchMode(let code, _): return code
        case .ioError(let code, _): return code
        case .encodingError(let code): return code
        }
    }
    
    public var errorDescription: String? {
        // Format error messages to match Rust implementation exactly
    }
}
```

### Phase 2: Vault Implementation

```swift
// Vault/Vault.swift
import Foundation

public struct Vault: Sendable {
    private let rootURL: URL
    
    public init(at path: String) throws {
        self.rootURL = URL(fileURLWithPath: path)
        try validate()
    }
    
    private func validate() throws {
        let aethelDir = rootURL.appendingPathComponent(".aethel")
        guard FileManager.default.fileExists(atPath: aethelDir.path) else {
            throw AethelError.ioError(message: "Not a valid vault: .aethel directory not found")
        }
    }
    
    public func readDoc(uuid: UUID) throws -> Doc {
        let docPath = rootURL
            .appendingPathComponent("docs")
            .appendingPathComponent("\(uuid).md")
        
        guard FileManager.default.fileExists(atPath: docPath.path) else {
            throw AethelError.docNotFound(uuid: uuid)
        }
        
        let content = try String(contentsOf: docPath)
        return try Doc(from: content)
    }
    
    public func writeDoc(_ doc: Doc) throws {
        let docPath = rootURL
            .appendingPathComponent("docs")
            .appendingPathComponent("\(doc.uuid).md")
        
        let content = doc.toMarkdown()
        try AtomicFileWriter.write(content, to: docPath)
    }
    
    // Additional vault operations...
}
```

### Phase 3: CLI Implementation

```swift
// AethelCLI/main.swift
import Foundation
import ArgumentParser
import AethelCore

@main
struct AethelCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aethel",
        abstract: "Aethel document management system",
        subcommands: [
            Init.self,
            Write.self,
            Read.self,
            Check.self,
            ListPacks.self,
            AddPack.self,
            RemovePack.self
        ]
    )
}

// Commands/Write.swift
struct Write: ParsableCommand {
    @Option(name: .long)
    var vaultRoot: String?
    
    @Option(name: .long)
    var json: String = "-"
    
    @Option(name: .long)
    var output: OutputFormat = .json
    
    // Test mode flags
    @Option(name: .long)
    var now: String?
    
    @Option(name: .long)
    var uuidSeed: String?
    
    func run() throws {
        let vault = try Vault(at: vaultRoot ?? ".")
        
        // Read JSON from stdin or file
        let inputData: Data
        if json == "-" {
            inputData = FileHandle.standardInput.readDataToEndOfFile()
        } else {
            inputData = try Data(contentsOf: URL(fileURLWithPath: json))
        }
        
        let patch = try JSONDecoder().decode(Patch.self, from: inputData)
        
        // Apply patch with test mode considerations
        let result = try vault.applyPatch(patch, testMode: TestMode.current)
        
        // Output result
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let outputData = try encoder.encode(result)
        
        FileHandle.standardOutput.write(outputData)
    }
}
```

### Phase 4: Golden Test Harness

Using Swift Testing framework:

```swift
// Tests/GoldenTests/GoldenTestRunner.swift
import Testing
import Foundation
@testable import AethelCore
@testable import AethelCLI

@Suite("Golden Tests")
struct GoldenTests {
    let testCasesPath = URL(fileURLWithPath: "../../tests/cases")
    
    @Test("Golden Test Suite", arguments: try loadTestCases())
    func runGoldenTest(_ testCase: TestCase) async throws {
        // Create temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Copy vault.before
        let vaultPath = tempDir.appendingPathComponent("vault")
        try copyDirectory(from: testCase.vaultBefore, to: vaultPath)
        
        // Run CLI command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/.build/debug/aethel")
        process.currentDirectoryURL = tempDir
        
        var args = ["--vault-root", vaultPath.path]
        args.append(contentsOf: testCase.cliArgs)
        
        // Add test mode arguments
        if let now = testCase.envVars["--now"] {
            args.append(contentsOf: ["--now", now])
        }
        if let uuidSeed = testCase.envVars["--uuid-seed"] {
            args.append(contentsOf: ["--uuid-seed", uuidSeed])
        }
        
        process.arguments = args
        process.environment = ["AETHEL_TEST_MODE": "1"]
        
        // Setup pipes for I/O
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Write input if needed
        if let input = testCase.inputJSON {
            inputPipe.fileHandleForWriting.write(input.data(using: .utf8)!)
            inputPipe.fileHandleForWriting.closeFile()
        }
        
        // Run process
        try process.run()
        process.waitUntilExit()
        
        // Verify results
        let exitCode = process.terminationStatus
        #expect(exitCode == testCase.expectExit)
        
        // Check output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)!
        
        switch testCase.expectOutput {
        case .json(let expected):
            let actual = try JSONSerialization.jsonObject(with: outputData)
            try compareJSON(expected, actual)
            
        case .markdown(let expected):
            #expect(normalizeMarkdown(output) == normalizeMarkdown(expected))
        }
        
        // Verify vault.after if present
        if let vaultAfter = testCase.vaultAfter {
            try compareDirectories(vaultPath, vaultAfter)
        }
    }
    
    static func loadTestCases() throws -> [TestCase] {
        let casesDir = URL(fileURLWithPath: "../../tests/cases")
        let entries = try FileManager.default.contentsOfDirectory(
            at: casesDir,
            includingPropertiesForKeys: nil
        )
        
        return try entries
            .filter { $0.hasDirectoryPath }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try TestCase(from: $0) }
    }
}

// Tests/GoldenTests/TestCase.swift
struct TestCase {
    let name: String
    let cliArgs: [String]
    let envVars: [String: String]
    let inputJSON: String?
    let expectExit: Int32
    let expectOutput: ExpectedOutput
    let vaultBefore: URL
    let vaultAfter: URL?
    
    enum ExpectedOutput {
        case json([String: Any])
        case markdown(String)
    }
    
    init(from caseDir: URL) throws {
        self.name = caseDir.lastPathComponent
        
        // Load CLI args
        let argsPath = caseDir.appendingPathComponent("cli-args.txt")
        let argsContent = try String(contentsOf: argsPath)
        self.cliArgs = argsContent.split(separator: " ").map(String.init)
        
        // Load env vars
        let envPath = caseDir.appendingPathComponent("env.json")
        if FileManager.default.fileExists(atPath: envPath.path) {
            let envData = try Data(contentsOf: envPath)
            self.envVars = try JSONDecoder().decode([String: String].self, from: envData)
        } else {
            self.envVars = [:]
        }
        
        // Load input
        let inputPath = caseDir.appendingPathComponent("input.json")
        if FileManager.default.fileExists(atPath: inputPath.path) {
            self.inputJSON = try String(contentsOf: inputPath)
        } else {
            self.inputJSON = nil
        }
        
        // Load expected exit code
        let exitPath = caseDir.appendingPathComponent("expect.exit.txt")
        let exitString = try String(contentsOf: exitPath).trimmingCharacters(in: .whitespacesAndNewlines)
        self.expectExit = Int32(exitString)!
        
        // Load expected output
        let jsonOutputPath = caseDir.appendingPathComponent("expect.stdout.json")
        let mdOutputPath = caseDir.appendingPathComponent("expect.stdout.md")
        
        if FileManager.default.fileExists(atPath: jsonOutputPath.path) {
            let data = try Data(contentsOf: jsonOutputPath)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            self.expectOutput = .json(json)
        } else if FileManager.default.fileExists(atPath: mdOutputPath.path) {
            let markdown = try String(contentsOf: mdOutputPath)
            self.expectOutput = .markdown(markdown)
        } else {
            throw TestError.missingExpectedOutput
        }
        
        // Load vault paths
        self.vaultBefore = caseDir.appendingPathComponent("vault.before")
        let vaultAfterPath = caseDir.appendingPathComponent("vault.after")
        self.vaultAfter = FileManager.default.fileExists(atPath: vaultAfterPath.path) ? vaultAfterPath : nil
    }
}
```

## Implementation Strategy

### Development Phases

1. **Week 1-2: Core Models and Parsing**
   - Implement Doc, Pack, Patch models
   - YAML front-matter parsing with Yams
   - Basic file I/O with atomic writes

2. **Week 2-3: JSON Schema Validation**
   - Port validation logic from Rust
   - Ensure identical error codes and messages
   - Unit test against known schemas

3. **Week 3-4: Vault Operations**
   - Complete vault implementation
   - Pack management
   - Patch application logic

4. **Week 4-5: CLI Implementation**
   - All command implementations
   - JSON I/O handling
   - Test mode support

5. **Week 5-6: Golden Test Integration**
   - Test harness implementation
   - Run against existing golden tests
   - Fix discrepancies

### Testing Strategy

1. **Unit Tests**: Test each component in isolation
2. **Integration Tests**: Test vault operations end-to-end
3. **Golden Tests**: Ensure 100% compatibility with Rust implementation
4. **Performance Tests**: Validate Swift implementation performance

### Key Compatibility Requirements

1. **Exact JSON Output**: JSON encoder must produce identical output
   - Sort keys alphabetically
   - Use consistent formatting
   - Handle null values identically

2. **Error Codes**: Must match protocol specification exactly
   - Same error codes
   - Same error message format
   - Same JSON error structure

3. **File System Behavior**:
   - Atomic writes using temp files
   - Same directory structure
   - Same file naming conventions

4. **YAML Processing**:
   - Handle edge cases identically
   - Preserve formatting where needed
   - Support same YAML features

## Dependencies

### Required
- **Yams**: YAML parsing (https://github.com/jpsim/Yams)
- **swift-argument-parser**: CLI framework

### Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AethelSwift",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AethelCore",
            targets: ["AethelCore"]
        ),
        .executable(
            name: "aethel",
            targets: ["AethelCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "AethelCore",
            dependencies: ["Yams"]
        ),
        .executableTarget(
            name: "AethelCLI",
            dependencies: [
                "AethelCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "AethelCoreTests",
            dependencies: ["AethelCore"]
        ),
        .testTarget(
            name: "GoldenTests",
            dependencies: ["AethelCore", "AethelCLI"]
        )
    ]
)
```

## Code Formatting

### Swift Format Setup

The project uses `swift-format` for consistent code formatting. Setup:

1. **Create BuildTools Package**:

```swift
// BuildTools/Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-format", from: "600.0.0")
    ],
    targets: [
        .target(name: "BuildTools", path: "")
    ]
)
```

2. **Format Script**:

```bash
#!/bin/bash
# scripts/run-swift-format.sh
set -e

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Run swift-format using Swift Package Manager
cd "$PROJECT_ROOT/BuildTools"
swift run swift-format "$@"
```

3. **Configuration File**:

```json
// .swift-format
{
  "version": 1,
  "lineLength": 100,
  "indentation": {
    "spaces": 4
  },
  "maximumBlankLines": 2,
  "respectsExistingLineBreaks": true,
  "lineBreakBeforeControlFlowKeywords": false,
  "lineBreakBeforeEachArgument": false
}
```

4. **Usage**:

```bash
# Format all Swift files
./scripts/run-swift-format.sh format --recursive Sources/ Tests/

# Check formatting (CI)
./scripts/run-swift-format.sh lint --recursive Sources/ Tests/

# Format in place
./scripts/run-swift-format.sh format --in-place --recursive Sources/ Tests/
```

5. **Makefile Integration**:

```makefile
# Makefile
.PHONY: format format-check

format:
	./scripts/run-swift-format.sh format --in-place --recursive Sources/ Tests/

format-check:
	./scripts/run-swift-format.sh lint --recursive Sources/ Tests/
```

## Success Criteria

1. All golden tests pass with identical output
2. Swift implementation can read/write vaults created by Rust implementation
3. Error handling matches protocol specification
4. Performance is acceptable for iOS/macOS use cases
5. Code is idiomatic Swift 6 with proper concurrency safety
6. Code passes swift-format linting

## Future Considerations

- Potential for SwiftUI property wrappers (post-MVP)
- Combine publishers for reactive vault updates (post-MVP)
- Performance optimizations using Swift 6 features
- Consider creating XCFramework for binary distribution