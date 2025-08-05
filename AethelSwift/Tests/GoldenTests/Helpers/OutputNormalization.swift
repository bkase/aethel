import Foundation

struct OutputNormalization {
    static func compareJSON(_ expected: [String: Any], _ actual: Any) throws {
        guard let actualDict = actual as? [String: Any] else {
            throw TestError.invalidTestCase("Expected JSON object, got \(type(of: actual))")
        }
        
        if !NSDictionary(dictionary: actualDict).isEqual(to: expected) {
            let expectedData = try JSONSerialization.data(withJSONObject: expected, options: [.prettyPrinted, .sortedKeys])
            let actualData = try JSONSerialization.data(withJSONObject: actualDict, options: [.prettyPrinted, .sortedKeys])
            
            let expectedString = String(data: expectedData, encoding: .utf8) ?? "Unable to serialize expected JSON"
            let actualString = String(data: actualData, encoding: .utf8) ?? "Unable to serialize actual JSON"
            
            throw TestError.invalidTestCase("JSON mismatch:\nExpected:\n\(expectedString)\n\nActual:\n\(actualString)")
        }
    }
    
    static func normalizeMarkdown(_ markdown: String) -> String {
        return markdown
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
    
    static func compareMarkdown(_ expected: String, _ actual: String) throws {
        let normalizedExpected = normalizeMarkdown(expected)
        let normalizedActual = normalizeMarkdown(actual)
        
        if normalizedExpected != normalizedActual {
            throw TestError.invalidTestCase("Markdown mismatch:\nExpected:\n\(normalizedExpected)\n\nActual:\n\(normalizedActual)")
        }
    }
}