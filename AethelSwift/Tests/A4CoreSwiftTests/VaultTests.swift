import XCTest
@testable import A4CoreSwift

final class VaultTests: XCTestCase {
    func testVaultInitWithValidDirectory() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vault = try! Vault(root: tempDir)
        XCTAssertEqual(vault.root.standardizedFileURL.path, tempDir.standardizedFileURL.path)
    }

    func testVaultInitWithMissingDirectory() {
        let missingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        XCTAssertThrowsError(try Vault(root: missingDir)) { error in
            guard case A4Error.vaultNotFound = error else {
                XCTFail("Expected vaultNotFound error")
                return
            }
        }
    }

    func testVaultInitWithFile() {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! "test".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        XCTAssertThrowsError(try Vault(root: tempFile)) { error in
            guard case A4Error.invalidVault = error else {
                XCTFail("Expected invalidVault error")
                return
            }
        }
    }

    func testResolveRelativeValid() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vault = try! Vault(root: tempDir)
        let resolved = try! vault.resolveRelative("subdir/file.md")

        XCTAssertEqual(
            resolved,
            tempDir.appendingPathComponent("subdir/file.md")
        )
    }

    func testResolveRelativeRejectsAbsolute() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vault = try! Vault(root: tempDir)

        XCTAssertThrowsError(try vault.resolveRelative("/etc/passwd")) { error in
            guard case A4Error.pathEscape = error else {
                XCTFail("Expected pathEscape error")
                return
            }
        }
    }

    func testResolveRelativeRejectsParentRefs() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vault = try! Vault(root: tempDir)

        XCTAssertThrowsError(try vault.resolveRelative("../escape.md")) { error in
            guard case A4Error.pathEscape = error else {
                XCTFail("Expected pathEscape error")
                return
            }
        }
    }

    func testVaultResolveWithMarker() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let markerDir = tempDir.appendingPathComponent(".a4")
        try! FileManager.default.createDirectory(
            at: markerDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let childDir = tempDir.appendingPathComponent("child")
        try! FileManager.default.createDirectory(at: childDir, withIntermediateDirectories: true)

        let (vault, origin) = try! Vault.resolve(
            cliPath: nil,
            env: [:],
            cwd: childDir
        )

        XCTAssertEqual(vault.root.standardizedFileURL.path, tempDir.standardizedFileURL.path)
        XCTAssertEqual(origin, .marker)
    }
}