import Foundation

public struct PathHelpers {
    public static func expandPath(_ path: String) -> String {
        let expandedPath = NSString(string: path).expandingTildeInPath
        return expandedPath
    }
    
    public static func isValidVault(at path: String) -> Bool {
        let expandedPath = expandPath(path)
        let aethelDir = URL(fileURLWithPath: expandedPath).appendingPathComponent(".aethel")
        return FileManager.default.fileExists(atPath: aethelDir.path)
    }
    
    public static func docPath(for uuid: UUID, in vaultPath: String) -> URL {
        let expandedPath = expandPath(vaultPath)
        return URL(fileURLWithPath: expandedPath)
            .appendingPathComponent("docs")
            .appendingPathComponent("\(uuid.uuidString).md")
    }
    
    public static func packPath(for name: String, in vaultPath: String) -> URL {
        let expandedPath = expandPath(vaultPath)
        return URL(fileURLWithPath: expandedPath)
            .appendingPathComponent("packs")
            .appendingPathComponent(name)
    }
}