import Testing
import Foundation
@testable import AethelCore

@Suite("Vault Tests")
struct VaultTests {
    
    @Test("Vault initialization")
    func testVaultInitialization() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try Vault.initialize(at: tempDir.path)
        
        _ = try Vault(at: tempDir.path)
        
        let aethelDir = tempDir.appendingPathComponent(".aethel")
        let docsDir = tempDir.appendingPathComponent("docs")
        let packsDir = aethelDir.appendingPathComponent("packs")
        
        #expect(FileManager.default.fileExists(atPath: aethelDir.path))
        #expect(FileManager.default.fileExists(atPath: docsDir.path))
        #expect(FileManager.default.fileExists(atPath: packsDir.path))
    }
    
    @Test("Vault operations - write and read doc")
    func testVaultWriteAndReadDoc() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try Vault.initialize(at: tempDir.path)
        let vault = try Vault(at: tempDir.path)
        
        let uuid = UUID()
        let frontMatter = ["title": "Test Document"]
        let body = "This is a test document."
        
        let doc = Doc(uuid: uuid, frontMatter: frontMatter, body: body)
        try vault.writeDoc(doc)
        
        let readDoc = try vault.readDoc(uuid: uuid)
        
        #expect(readDoc.uuid == uuid)
        #expect(readDoc.body == body)
        #expect(readDoc.frontMatterDict["title"] as? String == "Test Document")
    }
    
    @Test("Vault operations - doc not found")
    func testVaultDocNotFound() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try Vault.initialize(at: tempDir.path)
        let vault = try Vault(at: tempDir.path)
        
        let uuid = UUID()
        
        #expect(throws: AethelError.self) {
            try vault.readDoc(uuid: uuid)
        }
    }
    
    @Test("Vault operations - list empty docs")
    func testVaultListEmptyDocs() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try Vault.initialize(at: tempDir.path)
        let vault = try Vault(at: tempDir.path)
        
        let docs = try vault.listDocs()
        #expect(docs.isEmpty)
    }
    
    @Test("Invalid vault should fail")
    func testInvalidVault() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        #expect(throws: AethelError.self) {
            try Vault(at: tempDir.path)
        }
    }
}