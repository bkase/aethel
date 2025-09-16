import Foundation

public enum Headings {
    public static func ensureH2(textBytes: Data, heading: String) throws -> Data {
        guard let content = String(data: textBytes, encoding: .utf8) else {
            throw A4Error.encoding("Invalid UTF-8 in text bytes")
        }

        let lines = content.components(separatedBy: "\n")

        let h2Pattern = "## \(heading)"
        let h2PatternLower = h2Pattern.lowercased()

        for line in lines {
            if line.lowercased() == h2PatternLower {
                return textBytes
            }
        }

        var result = textBytes

        if !content.isEmpty && !content.hasSuffix("\n") {
            result.append("\n".data(using: .utf8)!)
        }

        if !content.isEmpty {
            result.append("\n".data(using: .utf8)!)
        }

        result.append("## \(heading)\n\n".data(using: .utf8)!)

        return result
    }
}