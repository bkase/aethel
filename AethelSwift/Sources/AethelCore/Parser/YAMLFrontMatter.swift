import Foundation
import Yams

public struct FrontMatterParser {
    private static let delimiter = "---\n"
    
    public static func parse(_ content: String) throws -> (frontMatter: [String: Any], body: String) {
        guard content.hasPrefix(delimiter) else {
            return ([:], content)
        }
        
        let contentAfterFirstDelimiter = String(content.dropFirst(delimiter.count))
        guard let endRange = contentAfterFirstDelimiter.range(of: "\n---\n") else {
            throw AethelError.malformedFrontMatter(message: "Missing closing front matter delimiter")
        }
        
        let yamlContent = String(contentAfterFirstDelimiter[..<endRange.lowerBound])
        let bodyStart = endRange.upperBound
        let body = String(contentAfterFirstDelimiter[bodyStart...])
        
        let frontMatter: [String: Any]
        if yamlContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            frontMatter = [:]
        } else {
            do {
                var rawFrontMatter = try Yams.load(yaml: yamlContent) as? [String: Any] ?? [:]
                
                // Convert Date objects back to ISO8601 strings to maintain consistency
                for (key, value) in rawFrontMatter {
                    if let dateValue = value as? Date {
                        rawFrontMatter[key] = ISO8601DateFormatter().string(from: dateValue)
                    }
                }
                
                frontMatter = rawFrontMatter
            } catch {
                throw AethelError.malformedFrontMatter(message: "Invalid YAML: \(error.localizedDescription)")
            }
        }
        
        return (frontMatter, body)
    }
    
    public static func serialize(frontMatter: [String: Any], body: String) throws -> String {
        guard !frontMatter.isEmpty else {
            return body
        }
        
        // Use specific ordering to match Rust output exactly
        let systemOrder = ["uuid", "type", "created", "updated", "v", "tags"]
        var yamlLines: [String] = []
        
        // Add system fields in order
        for key in systemOrder {
            if let value = frontMatter[key] {
                let yamlValue = serializeYAMLValue(value)
                yamlLines.append("\(key): \(yamlValue)")
            }
        }
        
        // Add user fields in alphabetical order
        let userFields = frontMatter.filter { key, _ in !systemOrder.contains(key) }
        let sortedUserFields = userFields.sorted { $0.key < $1.key }
        
        for (key, value) in sortedUserFields {
            let yamlValue = serializeYAMLValue(value)
            yamlLines.append("\(key): \(yamlValue)")
        }
        
        let yamlString = yamlLines.joined(separator: "\n")
        return "---\n\(yamlString)\n---\n\(body)"
    }
    
    private static func serializeYAMLValue(_ value: Any) -> String {
        switch value {
        case let stringValue as String:
            // Don't quote ISO8601 timestamps or simple strings that don't need quotes
            if stringValue.contains("T") && stringValue.contains("Z") {
                return stringValue
            } else if stringValue.contains(" ") || stringValue.contains(":") {
                return "'\(stringValue)'"
            } else {
                return stringValue
            }
        case let dateValue as Date:
            // Format Date objects as ISO8601 strings
            return ISO8601DateFormatter().string(from: dateValue)
        case let arrayValue as [Any]:
            if arrayValue.isEmpty {
                return "[]"
            } else {
                let items = arrayValue.map { serializeYAMLValue($0) }.joined(separator: ", ")
                return "[\(items)]"
            }
        case let numberValue as NSNumber:
            return numberValue.stringValue
        case let boolValue as Bool:
            return boolValue ? "true" : "false"
        default:
            return "\(value)"
        }
    }
}