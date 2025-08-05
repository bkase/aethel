import Foundation

public struct JSONSchema: Codable, Equatable {
    public let schema: String?
    public let type: JSONType?
    public let properties: [String: JSONSchema]?
    public let required: [String]?
    public let items: Box<JSONSchema>?
    public let additionalProperties: Either<Bool, Box<JSONSchema>>?
    public let minLength: Int?
    public let maxLength: Int?
    public let minimum: Double?
    public let maximum: Double?
    public let `enum`: [AnyCodable]?
    
    public enum JSONType: String, Codable, Sendable {
        case object
        case array
        case string
        case number
        case integer
        case boolean
        case null
    }
    
    public init(
        schema: String? = nil,
        type: JSONType? = nil,
        properties: [String: JSONSchema]? = nil,
        required: [String]? = nil,
        items: JSONSchema? = nil,
        additionalProperties: Either<Bool, Box<JSONSchema>>? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        enum: [Any]? = nil
    ) {
        self.schema = schema
        self.type = type
        self.properties = properties
        self.required = required
        self.items = items.map(Box.init)
        self.additionalProperties = additionalProperties
        self.minLength = minLength
        self.maxLength = maxLength
        self.minimum = minimum
        self.maximum = maximum
        self.enum = `enum`?.map(AnyCodable.init)
    }
    
    private enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case type
        case properties
        case required
        case items
        case additionalProperties
        case minLength
        case maxLength
        case minimum
        case maximum
        case `enum`
    }
}

public struct JSONPointer {
    public let path: [String]
    
    nonisolated(unsafe) public static let root = JSONPointer(path: [])
    
    public init(path: [String]) {
        self.path = path
    }
    
    public func appending(_ key: String) -> JSONPointer {
        return JSONPointer(path: path + [key])
    }
    
    public func appending(_ index: Int) -> JSONPointer {
        return JSONPointer(path: path + [String(index)])
    }
    
    public var description: String {
        return "/" + path.joined(separator: "/")
    }
}