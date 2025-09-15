import Foundation

public struct AppendOptions {
    public let heading: String
    public let anchor: AnchorToken
    public let content: Data

    public init(heading: String, anchor: AnchorToken, content: Data) {
        self.heading = heading
        self.anchor = anchor
        self.content = content
    }
}

public enum Append {
    public static func appendBlock(
        vault: Vault,
        targetFile: URL,
        opts: AppendOptions
    ) throws {
        guard String(data: opts.content, encoding: .utf8) != nil else {
            throw A4Error.encoding("Content is not valid UTF-8")
        }

        let existingData = try FileIO.readFile(at: targetFile)

        let split = Notes.splitFrontMatter(existingData)

        var bodyData = split.body

        bodyData = try Headings.ensureH2(textBytes: bodyData, heading: opts.heading)

        // Ensure exactly one blank line before the anchor
        if bodyData.count >= 2 {
            let lastByte = bodyData[bodyData.count - 1]
            let secondLastByte = bodyData[bodyData.count - 2]

            if lastByte != 10 {  // Not ending with newline
                bodyData.append("\n\n".data(using: .utf8)!)
            } else if secondLastByte != 10 {  // Only one newline at end
                bodyData.append("\n".data(using: .utf8)!)
            }
            // If already has two newlines (blank line), don't add more
        } else if bodyData.count == 1 {
            let lastByte = bodyData[bodyData.count - 1]
            if lastByte != 10 {
                bodyData.append("\n\n".data(using: .utf8)!)
            } else {
                bodyData.append("\n".data(using: .utf8)!)
            }
        } else {
            // Empty body - shouldn't happen after ensureH2
            bodyData.append("\n".data(using: .utf8)!)
        }

        let markerLine = opts.anchor.marker()
        bodyData.append("\(markerLine)\n".data(using: .utf8)!)

        bodyData.append(opts.content)

        if !opts.content.isEmpty {
            let lastByte = opts.content[opts.content.count - 1]
            if lastByte != 10 {
                bodyData.append("\n".data(using: .utf8)!)
            }
        }

        let finalData = Notes.joinFrontMatter(header: split.header, body: bodyData)

        let normalizedData = FileIO.normalizeLineEndings(finalData)
        let withTrailingNewline = FileIO.ensureTrailingNewline(normalizedData)

        try FileIO.atomicWrite(at: targetFile, data: withTrailingNewline)
    }
}