import Foundation

public struct AtomicFileWriter {
    public static func write(_ data: Data, to url: URL) throws {
        let tempURL = url.appendingPathExtension("tmp.\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            try data.write(to: tempURL)
            
            _ = try FileManager.default.replaceItem(
                at: url,
                withItemAt: tempURL,
                backupItemName: nil,
                options: [],
                resultingItemURL: nil
            )
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw AethelError.ioError(message: error.localizedDescription)
        }
    }
    
    public static func write(_ string: String, to url: URL) throws {
        guard let data = string.data(using: .utf8) else {
            throw AethelError.encodingError()
        }
        try write(data, to: url)
    }
}