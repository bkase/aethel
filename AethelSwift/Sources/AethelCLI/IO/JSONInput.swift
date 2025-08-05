import Foundation

public struct JSONInput {
    public static func readFromStdin() throws -> Data {
        return FileHandle.standardInput.readDataToEndOfFile()
    }
    
    public static func readFromFile(at path: String) throws -> Data {
        let url = URL(fileURLWithPath: path)
        return try Data(contentsOf: url)
    }
    
    public static func read(from source: String) throws -> Data {
        if source == "-" {
            return try readFromStdin()
        } else {
            return try readFromFile(at: source)
        }
    }
}