import Foundation
import AethelCore

public struct JSONOutput {
    public static func write<T: Codable>(_ value: T, format: OutputFormat = .json) throws {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            FileHandle.standardOutput.write(data)
            
        case .markdown:
            if let doc = value as? Doc {
                let markdown = doc.toMarkdown()
                if let data = markdown.data(using: String.Encoding.utf8) {
                    FileHandle.standardOutput.write(data)
                }
            } else {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(value)
                FileHandle.standardOutput.write(data)
            }
        }
    }
    
    public static func writeArray(_ array: [[String: Any]], format: OutputFormat = .json) throws {
        switch format {
        case .json:
            let data = try JSONSerialization.data(withJSONObject: array, options: [.prettyPrinted, .sortedKeys])
            FileHandle.standardOutput.write(data)
        case .markdown:
            // For markdown format, just write as JSON for now
            let data = try JSONSerialization.data(withJSONObject: array, options: [.prettyPrinted, .sortedKeys])
            FileHandle.standardOutput.write(data)
        }
    }
    
    public static func writeDictionary(_ dictionary: [String: Any], format: OutputFormat = .json) throws {
        switch format {
        case .json:
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
            FileHandle.standardOutput.write(data)
        case .markdown:
            // For markdown format, just write as JSON for now
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
            FileHandle.standardOutput.write(data)
        }
    }
    
    public static func writeError(_ error: AethelError) {
        let errorData = error.toJSON()
        do {
            let data = try JSONSerialization.data(withJSONObject: errorData, options: [.prettyPrinted, .sortedKeys])
            FileHandle.standardOutput.write(data)
        } catch {
            let fallbackError = "Internal error: failed to serialize error response"
            if let data = fallbackError.data(using: .utf8) {
                FileHandle.standardOutput.write(data)
            }
        }
    }
}