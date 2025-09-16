import XCTest
@testable import A4CoreSwift

final class FilesTests: XCTestCase {
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

    func testCreateNewFile() throws {
        let content = "# Test\n\nContent".data(using: .utf8)!

        try Files.writeMarkdown(
            vault: vault,
            at: "test.md",
            bytes: content,
            mode: .createNew
        )

        let targetFile = tempDir.appendingPathComponent("test.md")
        let result = try String(contentsOf: targetFile, encoding: .utf8)

        XCTAssertTrue(result.contains("# Test"))
        XCTAssertTrue(result.contains("Content"))
        XCTAssertTrue(result.hasSuffix("\n"))
    }

    func testCreateNewFailsIfExists() throws {
        let targetFile = tempDir.appendingPathComponent("test.md")
        try "existing".write(to: targetFile, atomically: true, encoding: .utf8)

        let content = "new".data(using: .utf8)!

        XCTAssertThrowsError(
            try Files.writeMarkdown(
                vault: vault,
                at: "test.md",
                bytes: content,
                mode: .createNew
            )
        ) { error in
            guard case A4Error.io = error else {
                XCTFail("Expected io error")
                return
            }
        }
    }

    func testCreateIfMissingSkipsExisting() throws {
        let targetFile = tempDir.appendingPathComponent("test.md")
        try "existing content".write(to: targetFile, atomically: true, encoding: .utf8)

        let content = "new content".data(using: .utf8)!

        try Files.writeMarkdown(
            vault: vault,
            at: "test.md",
            bytes: content,
            mode: .createIfMissing
        )

        let result = try String(contentsOf: targetFile, encoding: .utf8)
        XCTAssertEqual(result, "existing content")
    }

    func testCreateIfMissingCreatesNew() throws {
        let content = "new content".data(using: .utf8)!

        try Files.writeMarkdown(
            vault: vault,
            at: "test.md",
            bytes: content,
            mode: .createIfMissing
        )

        let targetFile = tempDir.appendingPathComponent("test.md")
        let result = try String(contentsOf: targetFile, encoding: .utf8)

        XCTAssertTrue(result.contains("new content"))
        XCTAssertTrue(result.hasSuffix("\n"))
    }

    func testOverwriteMode() throws {
        let targetFile = tempDir.appendingPathComponent("test.md")
        try "old content".write(to: targetFile, atomically: true, encoding: .utf8)

        let content = "new content".data(using: .utf8)!

        try Files.writeMarkdown(
            vault: vault,
            at: "test.md",
            bytes: content,
            mode: .overwrite
        )

        let result = try String(contentsOf: targetFile, encoding: .utf8)
        XCTAssertTrue(result.contains("new content"))
        XCTAssertFalse(result.contains("old content"))
        XCTAssertTrue(result.hasSuffix("\n"))
    }

    func testCreateWithSubdirectories() throws {
        let content = "content".data(using: .utf8)!

        try Files.writeMarkdown(
            vault: vault,
            at: "sub/dir/file.md",
            bytes: content,
            mode: .createNew
        )

        let targetFile = tempDir.appendingPathComponent("sub/dir/file.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFile.path))

        let result = try String(contentsOf: targetFile, encoding: .utf8)
        XCTAssertTrue(result.contains("content"))
    }

    func testEmptyFileGetsNewline() throws {
        let content = Data()

        try Files.writeMarkdown(
            vault: vault,
            at: "empty.md",
            bytes: content,
            mode: .createNew
        )

        let targetFile = tempDir.appendingPathComponent("empty.md")
        let result = try String(contentsOf: targetFile, encoding: .utf8)

        XCTAssertEqual(result, "\n")
    }

    func testLineEndingNormalization() throws {
        let content = "Line 1\r\nLine 2\rLine 3".data(using: .utf8)!

        try Files.writeMarkdown(
            vault: vault,
            at: "test.md",
            bytes: content,
            mode: .createNew
        )

        let targetFile = tempDir.appendingPathComponent("test.md")
        let result = try String(contentsOf: targetFile, encoding: .utf8)

        XCTAssertFalse(result.contains("\r"))
        XCTAssertTrue(result.contains("Line 1\nLine 2\nLine 3\n"))
    }
}