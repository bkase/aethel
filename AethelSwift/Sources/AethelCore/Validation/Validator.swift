import Foundation

public struct JSONSchemaValidator {
    private let schema: JSONSchema
    
    public init(schema: JSONSchema) {
        self.schema = schema
    }
    
    public func validate(_ value: Any) throws {
        try validateValue(value, against: schema, at: JSONPointer.root)
    }
    
    private func validateValue(_ value: Any, against schema: JSONSchema, at pointer: JSONPointer) throws {
        if let enumValues = schema.`enum` {
            try validateEnum(value, against: enumValues, at: pointer)
            return
        }
        
        if let type = schema.type {
            try validateType(value, against: type, at: pointer)
        }
        
        switch value {
        case let stringValue as String:
            try validateString(stringValue, against: schema, at: pointer)
            
        case let numberValue as NSNumber:
            try validateNumber(numberValue, against: schema, at: pointer)
            
        case let arrayValue as [Any]:
            try validateArray(arrayValue, against: schema, at: pointer)
            
        case let objectValue as [String: Any]:
            try validateObject(objectValue, against: schema, at: pointer)
            
        default:
            break
        }
    }
    
    private func validateEnum(_ value: Any, against enumValues: [AnyCodable], at pointer: JSONPointer) throws {
        for enumValue in enumValues {
            if areEqual(value, enumValue.value) {
                return
            }
        }
        throw AethelError.schemaValidationFailed(details: "Value at \(pointer.description) is not in enum")
    }
    
    private func validateType(_ value: Any, against type: JSONSchema.JSONType, at pointer: JSONPointer) throws {
        let isValid: Bool
        
        switch (type, value) {
        case (.null, is NSNull):
            isValid = true
        case (.boolean, is Bool):
            isValid = true
        case (.integer, let number as NSNumber):
            isValid = CFNumberIsFloatType(number) == false
        case (.number, is NSNumber):
            isValid = true
        case (.string, is String):
            isValid = true
        case (.array, is [Any]):
            isValid = true
        case (.object, is [String: Any]):
            isValid = true
        default:
            isValid = false
        }
        
        if !isValid {
            let valueString = "\"\(value)\""
            throw AethelError.schemaValidationFailed(
                details: "\(valueString) is not of type \"\(type.rawValue)\". Pointer: Some(\"\(pointer.description)\"), Expected: None, Got: Some(\"\\\(valueString)\")",
                pointer: pointer.description,
                expected: nil,
                got: valueString
            )
        }
    }
    
    private func validateString(_ value: String, against schema: JSONSchema, at pointer: JSONPointer) throws {
        if let minLength = schema.minLength, value.count < minLength {
            throw AethelError.schemaValidationFailed(details: "String at \(pointer.description) is shorter than minimum length \(minLength)")
        }
        
        if let maxLength = schema.maxLength, value.count > maxLength {
            throw AethelError.schemaValidationFailed(details: "String at \(pointer.description) is longer than maximum length \(maxLength)")
        }
    }
    
    private func validateNumber(_ value: NSNumber, against schema: JSONSchema, at pointer: JSONPointer) throws {
        let doubleValue = value.doubleValue
        
        if let minimum = schema.minimum, doubleValue < minimum {
            throw AethelError.schemaValidationFailed(details: "Number at \(pointer.description) is less than minimum \(minimum)")
        }
        
        if let maximum = schema.maximum, doubleValue > maximum {
            throw AethelError.schemaValidationFailed(details: "Number at \(pointer.description) is greater than maximum \(maximum)")
        }
    }
    
    private func validateArray(_ value: [Any], against schema: JSONSchema, at pointer: JSONPointer) throws {
        if let itemsSchema = schema.items?.value {
            for (index, item) in value.enumerated() {
                try validateValue(item, against: itemsSchema, at: pointer.appending(index))
            }
        }
    }
    
    private func validateObject(_ value: [String: Any], against schema: JSONSchema, at pointer: JSONPointer) throws {
        if let required = schema.required {
            for requiredKey in required {
                if value[requiredKey] == nil {
                    throw AethelError.schemaValidationFailed(details: "Required property '\(requiredKey)' missing at \(pointer.description)")
                }
            }
        }
        
        if let properties = schema.properties {
            for (key, propertyValue) in value {
                if let propertySchema = properties[key] {
                    try validateValue(propertyValue, against: propertySchema, at: pointer.appending(key))
                } else {
                    try validateAdditionalProperty(key, value: propertyValue, against: schema, at: pointer)
                }
            }
        }
    }
    
    private func validateAdditionalProperty(_ key: String, value: Any, against schema: JSONSchema, at pointer: JSONPointer) throws {
        switch schema.additionalProperties {
        case .left(false):
            throw AethelError.schemaValidationFailed(details: "Additional property '\(key)' not allowed at \(pointer.description)")
        case .left(true):
            break
        case .right(let schemaBox):
            try validateValue(value, against: schemaBox.value, at: pointer.appending(key))
        case .none:
            break
        }
    }
    
    private func areEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        switch (lhs, rhs) {
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
}