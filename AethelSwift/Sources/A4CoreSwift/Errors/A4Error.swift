import Foundation

public enum A4Error: Error, CustomStringConvertible {
    case vaultNotFound(String)
    case invalidVault(String)
    case invalidAnchor(String)
    case io(String)
    case encoding(String)
    case pathEscape(String)

    public var description: String {
        switch self {
        case .vaultNotFound(let message):
            return "Vault not found: \(message)"
        case .invalidVault(let message):
            return "Invalid vault: \(message)"
        case .invalidAnchor(let message):
            return "Invalid anchor: \(message)"
        case .io(let message):
            return "I/O error: \(message)"
        case .encoding(let message):
            return "Encoding error: \(message)"
        case .pathEscape(let message):
            return "Path escape attempt: \(message)"
        }
    }
}