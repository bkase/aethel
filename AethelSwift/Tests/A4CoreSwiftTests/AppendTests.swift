import XCTest
@testable import A4CoreSwift

final class AppendTests: XCTestCase {
    private var tempDir: URL!
    private var vault: Vault!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        vault = try! Vault(root: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testAppendToEmptyFile() throws {
        let targetFile = tempDir.appendingPathComponent("note.md")
        let anchor = try AnchorToken(parse: "test-1200")
        let content = "Test content".data(using: .utf8)!

        try Append.appendBlock(
            vault: vault,
            targetFile: targetFile,
            opts: AppendOptions(
                heading: "Journal",
                anchor: anchor,
                content: content
            )
        )

        let result = try String(contentsOf: targetFile, encoding: .utf8)
        XCTAssertTrue(result.contains("## Journal"))
        XCTAssertTrue(result.contains("^test-1200"))
        XCTAssertTrue(result.contains("Test content"))
        XCTAssertTrue(result.hasSuffix("\n"))
    }

    func testAppendToExistingH2() throws {
        let targetFile = tempDir.appendingPathComponent("note.md")
        try "## Journal\n\nExisting content\n".write(
            to: targetFile,
            atomically: true,
            encoding: .utf8
        )

        let anchor = try AnchorToken(parse: "test-1300")
        let content = "New content".data(using: .utf8)!

        try Append.appendBlock(
            vault: vault,
            targetFile: targetFile,
            opts: AppendOptions(
                heading: "Journal",
                anchor: anchor,
                content: content
            )
        )

        let result = try String(contentsOf: targetFile, encoding: .utf8)
        let h2Count = result.components(separatedBy: "## Journal").count - 1
        XCTAssertEqual(h2Count, 1, "Should not duplicate H2")
        XCTAssertTrue(result.contains("^test-1300"))
        XCTAssertTrue(result.contains("New content"))
    }

    func testAppendMultipleBlocks() throws {
        let targetFile = tempDir.appendingPathComponent("note.md")

        let anchor1 = try AnchorToken(parse: "test-1000")
        let content1 = "First block".data(using: .utf8)!

        try Append.appendBlock(
            vault: vault,
            targetFile: targetFile,
            opts: AppendOptions(
                heading: "Journal",
                anchor: anchor1,
                content: content1
            )
        )

        let anchor2 = try AnchorToken(parse: "test-1100")
        let content2 = "Second block".data(using: .utf8)!

        try Append.appendBlock(
            vault: vault,
            targetFile: targetFile,
            opts: AppendOptions(
                heading: "Journal",
                anchor: anchor2,
                content: content2
            )
        )

        let result = try String(contentsOf: targetFile, encoding: .utf8)
        XCTAssertTrue(result.contains("^test-1000"))
        XCTAssertTrue(result.contains("First block"))
        XCTAssertTrue(result.contains("^test-1100"))
        XCTAssertTrue(result.contains("Second block"))

        let firstIndex = result.range(of: "^test-1000")!.lowerBound
        let secondIndex = result.range(of: "^test-1100")!.lowerBound
        XCTAssertTrue(firstIndex < secondIndex)
    }

    func testAppendWithFrontMatter() throws {
        let targetFile = tempDir.appendingPathComponent("note.md")
        let initial = """
---
title: Test Note
date: 2025-01-01
---
# My Note

Content
"""
        try initial.write(to: targetFile, atomically: true, encoding: .utf8)

        let anchor = try AnchorToken(parse: "test-1400")
        let content = "Appended content".data(using: .utf8)!

        try Append.appendBlock(
            vault: vault,
            targetFile: targetFile,
            opts: AppendOptions(
                heading: "Journal",
                anchor: anchor,
                content: content
            )
        )

        let result = try String(contentsOf: targetFile, encoding: .utf8)
        XCTAssertTrue(result.hasPrefix("---\n"))
        XCTAssertTrue(result.contains("title: Test Note"))
        XCTAssertTrue(result.contains("^test-1400"))
        XCTAssertTrue(result.contains("Appended content"))
    }

    func testNewlineDiscipline() throws {
        let targetFile = tempDir.appendingPathComponent("note.md")
        try "## Journal\n\nExisting".write(
            to: targetFile,
            atomically: true,
            encoding: .utf8
        )

        let anchor = try AnchorToken(parse: "test-1500")
        let content = "New block".data(using: .utf8)!

        try Append.appendBlock(
            vault: vault,
            targetFile: targetFile,
            opts: AppendOptions(
                heading: "Journal",
                anchor: anchor,
                content: content
            )
        )

        let result = try String(contentsOf: targetFile, encoding: .utf8)

        let pattern = "Existing\n\n^test-1500\nNew block\n"
        XCTAssertTrue(result.contains(pattern))
        XCTAssertTrue(result.hasSuffix("\n"))
    }
}