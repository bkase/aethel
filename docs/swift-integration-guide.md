# A4CoreSwift Integration Guide

This guide explains how to integrate the A4CoreSwift library into your Swift applications (iOS, macOS, or other Apple platforms) to read from and write to an aethel (A4) vault.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Common Use Cases](#common-use-cases)
- [API Reference](#api-reference)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Installation

### Swift Package Manager

Add A4CoreSwift to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(path: "../path/to/aethel/AethelSwift")
]
```

Or if using Xcode, add it through File → Add Package Dependencies and point to the local path.

### Import the Module

```swift
import A4CoreSwift
```

## Quick Start

Here's a minimal example of appending content to today's daily note:

```swift
import A4CoreSwift
import Foundation

// 1. Find or create the vault
let (vault, origin) = try Vault.resolve(
    cliPath: nil,
    env: ProcessInfo.processInfo.environment,
    cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
)

// 2. Get today's daily note path
let now = Date()
let utcDay = Dates.utcDay(from: now)
let (year, yearMonth, filename) = Dates.dailyPathComponents(for: utcDay)
let dailyPath = "capture/\(year)/\(yearMonth)/\(filename)"
let dailyURL = try vault.resolveRelative(dailyPath)

// 3. Create an anchor for this entry
let hhmm = Dates.localHHMM(from: now)
let anchor = try AnchorToken(parse: "note-\(hhmm)")

// 4. Append content to the daily note
let content = "This is my note content".data(using: .utf8)!
try Append.appendBlock(
    vault: vault,
    targetFile: dailyURL,
    opts: AppendOptions(
        heading: "Notes",
        anchor: anchor,
        content: content
    )
)
```

## Core Concepts

### Vault

The vault is the root directory containing all your aethel notes. A4CoreSwift can find an existing vault through several methods:

1. **Explicit path**: Pass a specific directory URL
2. **Environment variable**: `A4_VAULT_DIR`
3. **Marker file**: Searches for `.a4` directory in parent folders
4. **Default location**: `~/Documents/a4-core`

### Daily Notes

Daily notes are the primary capture surface in aethel. They follow a strict directory structure:

```
capture/
  2025/
    2025-03/
      2025-03-15.md
```

The date in the filename is always in UTC, but timestamps within the file use local time.

### Anchors

Anchors are unique identifiers for content blocks within a note. They follow the format:

```
^prefix-HHMM__suffix
```

- **prefix**: lowercase letters, numbers, and hyphens (2-25 chars)
- **HHMM**: 4-digit local time (e.g., 1430 for 2:30 PM)
- **suffix**: optional device/context identifier

Examples:
- `^journal-0930` - Journal entry at 9:30 AM
- `^task-1245__iphone` - Task added from iPhone at 12:45 PM

### Headings

Content is organized under H2 headings (`## Heading`). The library automatically creates headings if they don't exist and preserves existing content structure.

## Common Use Cases

### 1. Quick Capture from iOS App

```swift
import A4CoreSwift
import UIKit

class QuickCaptureViewController: UIViewController {
    @IBOutlet weak var textView: UITextView!

    @IBAction func saveNote() {
        Task {
            do {
                // Find vault (likely in iCloud Drive or Documents)
                let documentsURL = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                ).first!

                let vaultURL = documentsURL.appendingPathComponent("a4-core")
                let vault = try Vault(root: vaultURL)

                // Create today's note path
                let now = Date()
                let day = Dates.utcDay(from: now)
                let (y, ym, file) = Dates.dailyPathComponents(for: day)
                let noteURL = try vault.resolveRelative("capture/\(y)/\(ym)/\(file)")

                // Create anchor with device identifier
                let hhmm = Dates.localHHMM(from: now)
                let anchor = try AnchorToken(parse: "capture-\(hhmm)__iphone")

                // Append the content
                let content = textView.text.data(using: .utf8)!
                try Append.appendBlock(
                    vault: vault,
                    targetFile: noteURL,
                    opts: AppendOptions(
                        heading: "Quick Capture",
                        anchor: anchor,
                        content: content
                    )
                )

                // Clear the text view
                textView.text = ""
                showSuccessMessage("Note saved!")

            } catch {
                showErrorMessage("Failed to save: \(error)")
            }
        }
    }
}
```

### 2. Journal Entry from macOS App

```swift
import A4CoreSwift
import SwiftUI

struct JournalView: View {
    @State private var entryText = ""
    @State private var mood = "😊"

    func saveJournalEntry() throws {
        // Resolve vault from environment or default location
        let (vault, _) = try Vault.resolve(
            cliPath: nil,
            env: ProcessInfo.processInfo.environment,
            cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )

        // Build today's path
        let now = Date()
        let day = Dates.utcDay(from: now)
        let (y, ym, file) = Dates.dailyPathComponents(for: day)
        let dailyNote = try vault.resolveRelative("capture/\(y)/\(ym)/\(file)")

        // Create formatted journal entry
        let entry = """
        Mood: \(mood)

        \(entryText)
        """

        // Create anchor for journal entry
        let hhmm = Dates.localHHMM(from: now)
        let anchor = try AnchorToken(parse: "journal-\(hhmm)")

        // Append to daily note
        try Append.appendBlock(
            vault: vault,
            targetFile: dailyNote,
            opts: AppendOptions(
                heading: "Journal",
                anchor: anchor,
                content: entry.data(using: .utf8)!
            )
        )
    }

    var body: some View {
        VStack {
            TextEditor(text: $entryText)
            HStack {
                Picker("Mood", selection: $mood) {
                    Text("😊").tag("😊")
                    Text("😐").tag("😐")
                    Text("😔").tag("😔")
                }
                Button("Save Entry") {
                    do {
                        try saveJournalEntry()
                        entryText = ""
                    } catch {
                        print("Error: \(error)")
                    }
                }
            }
        }
    }
}
```

### 3. Task Management Integration

```swift
import A4CoreSwift

class TaskManager {
    let vault: Vault

    init() throws {
        let (vault, _) = try Vault.resolve(
            cliPath: nil,
            env: ProcessInfo.processInfo.environment,
            cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )
        self.vault = vault
    }

    func addTask(_ task: String, dueDate: Date? = nil) throws {
        let now = Date()
        let day = Dates.utcDay(from: now)
        let (y, ym, file) = Dates.dailyPathComponents(for: day)
        let dailyNote = try vault.resolveRelative("capture/\(y)/\(ym)/\(file)")

        // Format task with checkbox
        var taskContent = "- [ ] \(task)"
        if let due = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            taskContent += " (Due: \(formatter.string(from: due)))"
        }

        let hhmm = Dates.localHHMM(from: now)
        let anchor = try AnchorToken(parse: "task-\(hhmm)")

        try Append.appendBlock(
            vault: vault,
            targetFile: dailyNote,
            opts: AppendOptions(
                heading: "Tasks",
                anchor: anchor,
                content: taskContent.data(using: .utf8)!
            )
        )
    }
}
```

### 4. Creating Source Notes

```swift
import A4CoreSwift

func createSourceNote(
    vault: Vault,
    title: String,
    url: String,
    highlights: [String],
    notes: String
) throws {
    let slug = title.lowercased()
        .replacingOccurrences(of: " ", with: "-")
        .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

    let content = """
    ---
    title: \(title)
    url: \(url)
    date: \(ISO8601DateFormatter().string(from: Date()))
    ---

    # \(title)

    Source: <\(url)>

    ## Highlights

    \(highlights.map { "> \($0)" }.joined(separator: "\n\n"))

    ## Notes

    \(notes)
    """

    try Files.writeMarkdown(
        vault: vault,
        at: "sources/articles/\(slug).md",
        bytes: content.data(using: .utf8)!,
        mode: .createNew
    )
}
```

### 5. Meeting Notes with Audio Transcription

```swift
import A4CoreSwift
import Speech

class MeetingNotesManager {
    func saveMeetingNotes(
        title: String,
        attendees: [String],
        transcript: String,
        actionItems: [String]
    ) throws {
        let (vault, _) = try Vault.resolve(
            cliPath: nil,
            env: ProcessInfo.processInfo.environment,
            cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )

        let now = Date()
        let day = Dates.utcDay(from: now)
        let (y, ym, file) = Dates.dailyPathComponents(for: day)
        let dailyNote = try vault.resolveRelative("capture/\(y)/\(ym)/\(file)")

        let content = """
        **Meeting:** \(title)
        **Attendees:** \(attendees.joined(separator: ", "))

        ### Transcript
        \(transcript)

        ### Action Items
        \(actionItems.map { "- [ ] \($0)" }.joined(separator: "\n"))
        """

        let hhmm = Dates.localHHMM(from: now)
        let anchor = try AnchorToken(parse: "meeting-\(hhmm)")

        try Append.appendBlock(
            vault: vault,
            targetFile: dailyNote,
            opts: AppendOptions(
                heading: "Meetings",
                anchor: anchor,
                content: content.data(using: .utf8)!
            )
        )
    }
}
```

## API Reference

### Vault

```swift
// Initialize with explicit path
let vault = try Vault(root: URL(fileURLWithPath: "/path/to/vault"))

// Auto-resolve vault location
let (vault, origin) = try Vault.resolve(
    cliPath: nil,  // Optional explicit path
    env: ProcessInfo.processInfo.environment,
    cwd: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
)

// Resolve a relative path within the vault
let noteURL = try vault.resolveRelative("capture/2025/2025-03/2025-03-15.md")
```

### Dates

```swift
// Convert Date to UTC day components
let utcDay = Dates.utcDay(from: Date())

// Get daily note path components
let (year, yearMonth, filename) = Dates.dailyPathComponents(for: utcDay)
// Returns: ("2025", "2025-03", "2025-03-15.md")

// Get local time as HHMM string
let hhmm = Dates.localHHMM(from: Date())  // "1430" for 2:30 PM
```

### Anchors

```swift
// Parse an anchor token
let anchor = try AnchorToken(parse: "journal-1430__macbook")

// Access components
print(anchor.prefix)  // "journal"
print(anchor.hhmm)     // "1430"
print(anchor.suffix)   // Optional("macbook")

// Get the full marker format
print(anchor.marker()) // "^journal-1430__macbook"
```

### Append Operations

```swift
let options = AppendOptions(
    heading: "Journal",           // H2 heading to use
    anchor: anchor,                // Validated anchor token
    content: "Entry text".data(using: .utf8)!
)

try Append.appendBlock(
    vault: vault,
    targetFile: noteURL,
    opts: options
)
```

### File Operations

```swift
// Create a new markdown file
try Files.writeMarkdown(
    vault: vault,
    at: "sources/notes/my-note.md",
    bytes: content.data(using: .utf8)!,
    mode: .createNew        // .createNew, .createIfMissing, or .overwrite
)
```

## Best Practices

### 1. Error Handling

Always wrap A4CoreSwift operations in proper error handling:

```swift
do {
    try Append.appendBlock(...)
} catch A4Error.vaultNotFound(let message) {
    // Handle missing vault
    print("Vault not found: \(message)")
} catch A4Error.invalidAnchor(let message) {
    // Handle invalid anchor format
    print("Invalid anchor: \(message)")
} catch A4Error.io(let message) {
    // Handle I/O errors
    print("I/O error: \(message)")
} catch {
    // Handle other errors
    print("Unexpected error: \(error)")
}
```

### 2. Thread Safety

A4CoreSwift operations are synchronous and should be called from background queues for better UI responsiveness:

```swift
Task {
    do {
        try await Task.detached(priority: .background) {
            try Append.appendBlock(...)
        }.value

        await MainActor.run {
            // Update UI on main thread
            updateUI()
        }
    } catch {
        // Handle error
    }
}
```

### 3. Vault Location for iOS

On iOS, store the vault in a location that syncs with iCloud:

```swift
let containerURL = FileManager.default.url(
    forUbiquityContainerIdentifier: nil
)?.appendingPathComponent("Documents/a4-core")

// Or use local documents directory
let documentsURL = FileManager.default.urls(
    for: .documentDirectory,
    in: .userDomainMask
).first!.appendingPathComponent("a4-core")
```

### 4. Anchor Naming Conventions

Use consistent, meaningful prefixes for different content types:

- `journal-` for journal entries
- `task-` for tasks
- `note-` for quick notes
- `meeting-` for meeting notes
- `idea-` for ideas
- `log-` for activity logs

### 5. Device Identifiers

Include device identifiers in anchors when syncing across devices:

```swift
#if os(iOS)
let deviceSuffix = UIDevice.current.name
    .lowercased()
    .replacingOccurrences(of: " ", with: "-")
    .replacingOccurrences(of: "'", with: "")
#else
let deviceSuffix = Host.current().localizedName?
    .lowercased()
    .replacingOccurrences(of: " ", with: "-") ?? "mac"
#endif

let anchor = try AnchorToken(parse: "note-\(hhmm)__\(deviceSuffix)")
```

## Troubleshooting

### Vault Not Found

**Problem**: `A4Error.vaultNotFound` when trying to resolve vault.

**Solution**: Ensure the vault exists at one of the expected locations:
- Set `A4_VAULT_DIR` environment variable
- Create `.a4` marker directory in a parent folder
- Initialize vault at `~/Documents/a4-core`

### Invalid Anchor Format

**Problem**: `A4Error.invalidAnchor` when creating anchors.

**Solution**: Ensure anchor follows the format:
- Prefix: lowercase letters, numbers, hyphens (2-25 chars)
- Time: Valid HHMM format (0000-2359)
- Suffix: Optional, after double underscore

### File Access Issues on iOS

**Problem**: Cannot write to vault on iOS.

**Solution**:
- Request appropriate file access permissions
- Use app's Documents directory or iCloud container
- Ensure app has necessary entitlements

### Front Matter Preservation

**Problem**: YAML front matter getting corrupted.

**Solution**: A4CoreSwift automatically preserves front matter. Don't manually parse or modify it when using `Append.appendBlock`.

## Examples Repository

For complete example applications, see:
- [iOS Quick Capture App Example]
- [macOS Menu Bar App Example]
- [SwiftUI Journal App Example]

## Support

For issues or questions:
- File issues on [GitHub Issues](https://github.com/yourusername/aethel/issues)
- Review the [A4 Protocol Specification](protocol.md)
- Check the [Swift Implementation SDD](swift-plan.md)