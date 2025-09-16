import Foundation

public enum CreateMode {
    case createNew
    case createIfMissing
    case overwrite
}

public enum Files {
    public static func writeMarkdown(
        vault: Vault,
        at relativePath: String,
        bytes: Data,
        mode: CreateMode
    ) throws {
        let targetURL = try vault.resolveRelative(relativePath)

        let fileExists = FileManager.default.fileExists(atPath: targetURL.path)

        switch mode {
        case .createNew:
            if fileExists {
                throw A4Error.io("File already exists at \(targetURL.path)")
            }
        case .createIfMissing:
            if fileExists {
                return
            }
        case .overwrite:
            break
        }

        let normalizedData = FileIO.normalizeLineEndings(bytes)
        let finalData = FileIO.ensureTrailingNewline(normalizedData)

        try FileIO.atomicWrite(at: targetURL, data: finalData)
    }
}