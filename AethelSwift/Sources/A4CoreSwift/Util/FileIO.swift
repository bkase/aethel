import Foundation

enum FileIO {
    static func atomicWrite(at url: URL, data: Data) throws {
        let directory = url.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let tempURL = directory.appendingPathComponent(".\(url.lastPathComponent).tmp")

        do {
            try data.write(to: tempURL, options: .atomic)

            _ = try FileManager.default.replaceItem(
                at: url,
                withItemAt: tempURL,
                backupItemName: nil,
                options: [],
                resultingItemURL: nil
            )
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw A4Error.io("Failed to write file atomically: \(error)")
        }
    }

    static func readFile(at url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError {
                return Data()
            }
            throw A4Error.io("Failed to read file: \(error)")
        }
    }

    static func ensureTrailingNewline(_ data: Data) -> Data {
        guard !data.isEmpty else {
            return "\n".data(using: .utf8)!
        }

        let lastByte = data[data.count - 1]
        if lastByte != 10 {  // '\n' is 10 in ASCII
            var result = data
            result.append("\n".data(using: .utf8)!)
            return result
        }

        return data
    }

    static func normalizeLineEndings(_ data: Data) -> Data {
        guard let content = String(data: data, encoding: .utf8) else {
            return data
        }

        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return normalized.data(using: .utf8) ?? data
    }
}