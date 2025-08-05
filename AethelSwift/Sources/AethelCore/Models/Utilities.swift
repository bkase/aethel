import Foundation

public final class Box<T>: Codable, Equatable where T: Codable & Equatable {
    public let value: T
    
    public init(_ value: T) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(T.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
    public static func == (lhs: Box<T>, rhs: Box<T>) -> Bool {
        return lhs.value == rhs.value
    }
}

public enum Either<A, B>: Codable, Equatable where A: Codable & Equatable, B: Codable & Equatable {
    case left(A)
    case right(B)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let leftValue = try? container.decode(A.self) {
            self = .left(leftValue)
        } else if let rightValue = try? container.decode(B.self) {
            self = .right(rightValue)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Could not decode Either<\(A.self), \(B.self)>"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .left(let value):
            try container.encode(value)
        case .right(let value):
            try container.encode(value)
        }
    }
}

public struct AnyCodable: Codable, Equatable {
    public let value: Any
    
    public init<T>(_ value: T) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Could not decode Any value"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map(AnyCodable.init))
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues(AnyCodable.init))
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Cannot encode value of type \(type(of: value))"
                )
            )
        }
    }
    
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        func areEqual(_ left: Any, _ right: Any) -> Bool {
            switch (left, right) {
            case (let l as NSNull, let r as NSNull):
                return l == r
            case (let l as Bool, let r as Bool):
                return l == r
            case (let l as NSNumber, let r as NSNumber):
                return l == r
            case (let l as String, let r as String):
                return l == r
            case (let l as [Any], let r as [Any]):
                guard l.count == r.count else { return false }
                return zip(l, r).allSatisfy(areEqual)
            case (let l as [String: Any], let r as [String: Any]):
                return NSDictionary(dictionary: l).isEqual(to: r)
            default:
                return false
            }
        }
        return areEqual(lhs.value, rhs.value)
    }
}