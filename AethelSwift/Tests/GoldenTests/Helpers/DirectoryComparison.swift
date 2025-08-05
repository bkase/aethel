import Foundation

struct DirectoryComparison {
    static func compareDirectories(_ actualURL: URL, _ expectedURL: URL) throws {
        let actualContents = try getDirectoryContents(actualURL)
        let expectedContents = try getDirectoryContents(expectedURL)
        
        // Compare file lists
        let actualFiles = Set(actualContents.keys)
        let expectedFiles = Set(expectedContents.keys)
        
        let missingFiles = expectedFiles.subtracting(actualFiles)
        let extraFiles = actualFiles.subtracting(expectedFiles)
        
        if !missingFiles.isEmpty {
            throw TestError.invalidTestCase("Missing files: \(missingFiles.joined(separator: ", "))")
        }
        
        if !extraFiles.isEmpty {
            throw TestError.invalidTestCase("Extra files: \(extraFiles.joined(separator: ", "))")
        }
        
        // Compare file contents
        for (relativePath, expectedContent) in expectedContents {
            guard let actualContent = actualContents[relativePath] else {
                throw TestError.invalidTestCase("Missing file: \(relativePath)")
            }
            
            if actualContent != expectedContent {
                throw TestError.invalidTestCase("File content mismatch: \(relativePath)")
            }
        }
    }
    
    private static func getDirectoryContents(_ url: URL) throws -> [String: Data] {
        var contents: [String: Data] = [:]
        
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        guard let enumerator = enumerator else {
            throw TestError.invalidTestCase("Could not enumerate directory: \(url.path)")
        }
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            
            if resourceValues.isRegularFile == true {
                let relativePath = String(fileURL.path.dropFirst(url.path.count + 1))
                let data = try Data(contentsOf: fileURL)
                contents[relativePath] = data
            }
        }
        
        return contents
    }
    
    static func copyDirectory(from source: URL, to destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        
        try FileManager.default.copyItem(at: source, to: destination)
    }
}