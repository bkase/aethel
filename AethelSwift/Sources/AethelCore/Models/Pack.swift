import Foundation

public struct Pack: Codable, Equatable {
    public let name: String
    public let version: String
    public let protocolVersion: String
    public let types: [PackType]
    public let templates: [String: Template]?
    public let migrations: [Migration]?
    
    public init(name: String, version: String, protocolVersion: String, types: [PackType] = [], templates: [String: Template]? = nil, migrations: [Migration]? = nil) {
        self.name = name
        self.version = version
        self.protocolVersion = protocolVersion
        self.types = types
        self.templates = templates
        self.migrations = migrations
    }
    
    public struct PackType: Codable, Equatable {
        public let id: String
        public let version: String
        public let schema: String?
        public let template: String?
        
        public init(id: String, version: String, schema: String? = nil, template: String? = nil) {
            self.id = id
            self.version = version
            self.schema = schema
            self.template = template
        }
    }
    
    public struct Template: Codable, Equatable {
        public let frontMatter: [String: AnyCodable]?
        public let body: String?
        
        public init(frontMatter: [String: Any]? = nil, body: String? = nil) {
            self.frontMatter = frontMatter?.mapValues(AnyCodable.init)
            self.body = body
        }
        
        public var frontMatterDict: [String: Any]? {
            return frontMatter?.mapValues { $0.value }
        }
        
        public static func == (lhs: Template, rhs: Template) -> Bool {
            return lhs.body == rhs.body &&
                   NSDictionary(dictionary: lhs.frontMatterDict ?? [:]).isEqual(to: rhs.frontMatterDict ?? [:])
        }
    }
    
    public struct Migration: Codable, Sendable, Equatable {
        public let from: String
        public let to: String
        public let script: String
        
        public init(from: String, to: String, script: String) {
            self.from = from
            self.to = to
            self.script = script
        }
    }
    
    public static func == (lhs: Pack, rhs: Pack) -> Bool {
        return lhs.name == rhs.name &&
               lhs.version == rhs.version &&
               lhs.protocolVersion == rhs.protocolVersion &&
               lhs.types == rhs.types &&
               lhs.templates == rhs.templates &&
               lhs.migrations == rhs.migrations
    }
}