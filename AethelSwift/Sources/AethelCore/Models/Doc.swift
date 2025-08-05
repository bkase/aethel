import Foundation

public struct Doc: Codable, Equatable {
    public let uuid: UUID
    public let frontMatter: [String: AnyCodable]
    public let body: String
    
    public init(uuid: UUID, frontMatter: [String: Any] = [:], body: String = "") {
        self.uuid = uuid
        self.frontMatter = frontMatter.mapValues(AnyCodable.init)
        self.body = body
    }
    
    public init(from markdown: String) throws {
        let (frontMatterDict, bodyContent) = try FrontMatterParser.parse(markdown)
        
        guard let uuidString = frontMatterDict["uuid"] as? String,
              let parsedUuid = UUID(uuidString: uuidString) else {
            throw AethelError.malformedFrontMatter(message: "Missing or invalid uuid field")
        }
        
        self.uuid = parsedUuid
        self.frontMatter = frontMatterDict.mapValues(AnyCodable.init)
        self.body = bodyContent
    }
    
    public func toMarkdown() -> String {
        do {
            // Order fields to match Rust implementation
            var orderedFrontMatter: [String: Any] = [:]
            let rawFrontMatter = self.frontMatterDict
            
            // System fields first in specific order
            orderedFrontMatter["uuid"] = uuid.uuidString.lowercased()
            if let type = rawFrontMatter["type"] { orderedFrontMatter["type"] = type }
            if let created = rawFrontMatter["created"] { orderedFrontMatter["created"] = created }
            if let updated = rawFrontMatter["updated"] { orderedFrontMatter["updated"] = updated }
            if let v = rawFrontMatter["v"] { orderedFrontMatter["v"] = v }
            if let tags = rawFrontMatter["tags"] { orderedFrontMatter["tags"] = tags }
            
            // Then user fields in alphabetical order
            let userFields = rawFrontMatter.filter { key, _ in
                !["uuid", "type", "created", "updated", "v", "tags"].contains(key)
            }.sorted { $0.key < $1.key }
            
            for (key, value) in userFields {
                orderedFrontMatter[key] = value
            }
            
            return try FrontMatterParser.serialize(
                frontMatter: orderedFrontMatter,
                body: body
            )
        } catch {
            return body
        }
    }
    
    public var frontMatterDict: [String: Any] {
        return frontMatter.mapValues { $0.value }
    }
    
    // Create a new doc with system metadata for creation
    public static func createNew(
        uuid: UUID,
        type: String,
        frontMatter: [String: Any],
        body: String,
        now: Date = Date()
    ) -> Doc {
        var completeFrontMatter = frontMatter
        completeFrontMatter["uuid"] = uuid.uuidString.lowercased()
        completeFrontMatter["type"] = type
        completeFrontMatter["created"] = ISO8601DateFormatter().string(from: now)
        completeFrontMatter["updated"] = ISO8601DateFormatter().string(from: now)
        completeFrontMatter["v"] = "1.0.0"
        completeFrontMatter["tags"] = []
        
        return Doc(uuid: uuid, frontMatter: completeFrontMatter, body: body)
    }
    
    // Update existing doc
    public func updated(frontMatter: [String: Any]? = nil, body: String? = nil, now: Date = Date()) -> Doc {
        var newFrontMatter = self.frontMatterDict
        
        if let frontMatter = frontMatter {
            for (key, value) in frontMatter {
                newFrontMatter[key] = value
            }
        }
        
        newFrontMatter["updated"] = ISO8601DateFormatter().string(from: now)
        
        return Doc(
            uuid: self.uuid,
            frontMatter: newFrontMatter,
            body: body ?? self.body
        )
    }
    
    public static func == (lhs: Doc, rhs: Doc) -> Bool {
        return lhs.uuid == rhs.uuid &&
               lhs.body == rhs.body &&
               NSDictionary(dictionary: lhs.frontMatterDict).isEqual(to: rhs.frontMatterDict)
    }
}