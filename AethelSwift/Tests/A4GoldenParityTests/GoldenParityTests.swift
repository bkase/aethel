import XCTest
@testable import A4CoreSwift

final class MockDateProvider: DateProvider {
    let fixedDate: Date

    init(fixedDate: Date) {
        self.fixedDate = fixedDate
    }

    func now() -> Date {
        fixedDate
    }
}

final class GoldenParityTests: XCTestCase {
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

    func testAppendGoldenCase1() throws {
        let targetFile = tempDir.appendingPathComponent("note.md")

        let anchor = try AnchorToken(parse: "test-0930")
        let content = "This is test content.".data(using: .utf8)!

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

        let expected = """
## Journal

^test-0930
This is test content.

"""
        XCTAssertEqual(result, expected)
    }

    func testAppendWithFrontMatterGoldenCase() throws {
        let targetFile = tempDir.appendingPathComponent("note.md")

        let initial = """
---
title: My Note
date: 2025-01-15
---
# Title

Some content here.
"""
        try initial.write(to: targetFile, atomically: true, encoding: .utf8)

        let anchor = try AnchorToken(parse: "jrnl-1045__macbook")
        let content = "Journal entry content.".data(using: .utf8)!

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

        let expected = """
---
title: My Note
date: 2025-01-15
---
# Title

Some content here.

## Journal

^jrnl-1045__macbook
Journal entry content.

"""
        XCTAssertEqual(result, expected)
    }

    func testMultipleAppendsGoldenCase() throws {
        let targetFile = tempDir.appendingPathComponent("daily.md")

        try "# Daily Note\n\nMorning thoughts.\n".write(
            to: targetFile,
            atomically: true,
            encoding: .utf8
        )

        let anchor1 = try AnchorToken(parse: "focus-0900")
        try Append.appendBlock(
            vault: vault,
            targetFile: targetFile,
            opts: AppendOptions(
                heading: "Focus",
                anchor: anchor1,
                content: "Working on Swift implementation.".data(using: .utf8)!
            )
        )

        let anchor2 = try AnchorToken(parse: "focus-1030")
        try Append.appendBlock(
            vault: vault,
            targetFile: targetFile,
            opts: AppendOptions(
                heading: "Focus",
                anchor: anchor2,
                content: "Testing the implementation.".data(using: .utf8)!
            )
        )

        let result = try String(contentsOf: targetFile, encoding: .utf8)

        let expected = """
# Daily Note

Morning thoughts.

## Focus

^focus-0900
Working on Swift implementation.

^focus-1030
Testing the implementation.

"""
        XCTAssertEqual(result, expected)
    }

    func testCreateMarkdownGoldenCase() throws {
        let content = """
# New Document

This is a new markdown document.

## Section 1

Content goes here.
""".data(using: .utf8)!

        try Files.writeMarkdown(
            vault: vault,
            at: "docs/new-doc.md",
            bytes: content,
            mode: .createNew
        )

        let targetFile = tempDir.appendingPathComponent("docs/new-doc.md")
        let result = try String(contentsOf: targetFile, encoding: .utf8)

        let expected = """
# New Document

This is a new markdown document.

## Section 1

Content goes here.

"""
        XCTAssertEqual(result, expected)
    }

    func testDailyPathGeneration() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        let testDate = dateFormatter.date(from: "2025-03-15 14:30:00")!
        let utcDay = Dates.utcDay(from: testDate)
        let (year, yearMonth, filename) = Dates.dailyPathComponents(for: utcDay)

        XCTAssertEqual(year, "2025")
        XCTAssertEqual(yearMonth, "2025-03")
        XCTAssertEqual(filename, "2025-03-15.md")

        let expectedPath = "capture/2025/2025-03/2025-03-15.md"
        let actualPath = "capture/\(year)/\(yearMonth)/\(filename)"
        XCTAssertEqual(actualPath, expectedPath)
    }
}