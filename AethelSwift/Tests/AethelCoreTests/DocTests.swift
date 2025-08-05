import Testing
import Foundation
@testable import AethelCore

@Suite("Doc Tests")
struct DocTests {
    
    @Test("Doc creation and serialization")
    func testDocCreationAndSerialization() throws {
        let uuid = UUID()
        let frontMatter = ["title": "Test Document", "author": "Test Author"]
        let body = "This is a test document."
        
        let doc = Doc(uuid: uuid, frontMatter: frontMatter, body: body)
        
        #expect(doc.uuid == uuid)
        #expect(doc.body == body)
        #expect(doc.frontMatterDict["title"] as? String == "Test Document")
        #expect(doc.frontMatterDict["author"] as? String == "Test Author")
    }
    
    @Test("Doc from markdown parsing")
    func testDocFromMarkdown() throws {
        let uuid = UUID()
        let markdown = """
        ---
        uuid: \(uuid.uuidString)
        title: Test Document
        author: Test Author
        ---
        This is a test document.
        """
        
        let doc = try Doc(from: markdown)
        
        #expect(doc.uuid == uuid)
        #expect(doc.body == "This is a test document.")
        #expect(doc.frontMatterDict["title"] as? String == "Test Document")
        #expect(doc.frontMatterDict["author"] as? String == "Test Author")
    }
    
    @Test("Doc to markdown conversion")
    func testDocToMarkdown() throws {
        let uuid = UUID()
        let frontMatter = ["title": "Test Document"]
        let body = "This is a test document."
        
        let doc = Doc(uuid: uuid, frontMatter: frontMatter, body: body)
        let markdown = doc.toMarkdown()
        
        #expect(markdown.contains("uuid: \(uuid.uuidString)"))
        #expect(markdown.contains("title: Test Document"))
        #expect(markdown.contains("This is a test document."))
    }
    
    @Test("Doc parsing with missing UUID should fail")
    func testDocParsingWithMissingUUID() throws {
        let markdown = """
        ---
        title: Test Document
        ---
        This is a test document.
        """
        
        #expect(throws: AethelError.self) {
            try Doc(from: markdown)
        }
    }
    
    @Test("Doc parsing with no front matter")
    func testDocParsingWithNoFrontMatter() throws {
        let markdown = "This is a test document without front matter."
        
        #expect(throws: AethelError.self) {
            try Doc(from: markdown)
        }
    }
}