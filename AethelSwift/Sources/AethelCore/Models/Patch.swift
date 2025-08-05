import Foundation

public struct Patch: Codable, Equatable {
    public enum Mode: String, Codable, Sendable, CaseIterable {
        case create
        case append
        case mergeFrontmatter = "merge_frontmatter"
        case replaceBody = "replace_body"
    }
    
    public let uuid: UUID?
    public let type: String?
    public let frontmatter: [String: AnyCodable]?
    public let body: String?
    public let mode: Mode
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case type
        case frontmatter
        case body
        case mode
    }
    
    public init(uuid: UUID? = nil, type: String? = nil, frontmatter: [String: Any]? = nil, body: String? = nil, mode: Mode) {
        self.uuid = uuid
        self.type = type
        self.frontmatter = frontmatter?.mapValues(AnyCodable.init)
        self.body = body
        self.mode = mode
    }
    
    public var frontmatterDict: [String: Any]? {
        return frontmatter?.mapValues { $0.value }
    }
    
    private static let systemKeys: Set<String> = ["uuid", "type", "created", "updated", "v", "tags"]
    
    public func validate() throws {
        switch mode {
        case .create:
            if type == nil {
                throw AethelError.malformedInput(message: "type field is required for create mode")
            }
            if uuid != nil {
                throw AethelError.malformedInput(message: "UUID must be null for create mode")
            }
        case .replaceBody:
            if body == nil {
                throw AethelError.malformedInput(message: "body field is required for replace_body mode")
            }
        default:
            break
        }
        
        // Check for system keys in frontmatter
        if let frontmatterDict = frontmatterDict {
            for key in frontmatterDict.keys {
                if Self.systemKeys.contains(key) {
                    throw AethelError.malformedInput(message: "Cannot set system key: \(key)")
                }
            }
        }
    }
    
    public static func == (lhs: Patch, rhs: Patch) -> Bool {
        return lhs.uuid == rhs.uuid &&
               lhs.type == rhs.type &&
               lhs.body == rhs.body &&
               lhs.mode == rhs.mode &&
               NSDictionary(dictionary: lhs.frontmatterDict ?? [:]).isEqual(to: rhs.frontmatterDict ?? [:])
    }
}