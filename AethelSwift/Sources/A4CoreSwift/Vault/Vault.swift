import Foundation

public struct Vault: Sendable {
    public let root: URL

    public init(root: URL) throws {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: root.path,
            isDirectory: &isDirectory
        )

        guard exists else {
            throw A4Error.vaultNotFound(root.path)
        }

        guard isDirectory.boolValue else {
            throw A4Error.invalidVault("\(root.path) exists but is not a directory")
        }

        self.root = root
    }

    public enum VaultOrigin: Sendable {
        case cli
        case env
        case marker
        case fallback
    }

    public static func resolve(
        cliPath: URL?,
        env: [String: String],
        cwd: URL
    ) throws -> (vault: Vault, origin: VaultOrigin) {
        if let cliPath = cliPath {
            do {
                let vault = try Vault(root: cliPath)
                return (vault, .cli)
            } catch {
                throw A4Error.vaultNotFound(
                    "CLI path specified but not valid: \(cliPath.path) - \(error)"
                )
            }
        }

        if let envPath = env["A4_VAULT_DIR"] {
            let url = URL(fileURLWithPath: envPath)
            do {
                let vault = try Vault(root: url)
                return (vault, .env)
            } catch {
                // Continue to next strategy
            }
        }

        var currentDir = cwd
        let fileManager = FileManager.default
        while currentDir.path != "/" {
            let markerPath = currentDir.appendingPathComponent(".a4")
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: markerPath.path, isDirectory: &isDirectory),
               isDirectory.boolValue
            {
                do {
                    let vault = try Vault(root: currentDir)
                    return (vault, .marker)
                } catch {
                    // Continue searching
                }
            }
            currentDir = currentDir.deletingLastPathComponent()
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let fallbackPath = homeDir
            .appendingPathComponent("Documents")
            .appendingPathComponent("a4-core")

        do {
            let vault = try Vault(root: fallbackPath)
            return (vault, .fallback)
        } catch {
            var triedStrategies: [String] = []
            if cliPath != nil {
                triedStrategies.append("CLI path")
            }
            if env["A4_VAULT_DIR"] != nil {
                triedStrategies.append("A4_VAULT_DIR environment variable")
            }
            triedStrategies.append("ancestor .a4 marker from \(cwd.path)")
            triedStrategies.append("fallback at \(fallbackPath.path)")

            throw A4Error.vaultNotFound(
                "No vault found. Tried: \(triedStrategies.joined(separator: ", "))"
            )
        }
    }

    public func resolveRelative(_ rel: String) throws -> URL {
        guard !rel.hasPrefix("/") else {
            throw A4Error.pathEscape("Absolute paths not allowed: \(rel)")
        }

        guard !rel.contains("..") else {
            throw A4Error.pathEscape("Parent directory references not allowed: \(rel)")
        }

        let targetURL = root.appendingPathComponent(rel)

        let canonicalRoot = root.standardizedFileURL.path
        let canonicalTarget = targetURL.standardizedFileURL.path

        guard canonicalTarget.hasPrefix(canonicalRoot) else {
            throw A4Error.pathEscape(
                "Path '\(rel)' would escape vault root"
            )
        }

        return targetURL
    }
}