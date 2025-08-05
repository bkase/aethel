import Foundation

public enum AethelError: LocalizedError, Codable {
    case malformedInput(code: Int = 40000, message: String)
    case malformedFrontMatter(code: Int = 40001, message: String)
    
    case docNotFound(code: Int = 40400, uuid: UUID)
    case packNotFound(code: Int = 40401, name: String)
    
    case docAlreadyExists(code: Int = 40900, uuid: UUID)
    case packAlreadyExists(code: Int = 40901, name: String)
    case typeMismatch(code: Int = 40902, docType: String, patchType: String)
    
    case schemaValidationFailed(code: Int = 42200, details: String, pointer: String? = nil, expected: String? = nil, got: String? = nil)
    case invalidPatchMode(code: Int = 42201, mode: String)
    
    case ioError(code: Int = 50000, message: String)
    case encodingError(code: Int = 50001)
    
    public var errorCode: Int {
        switch self {
        case .malformedInput(let code, _): return code
        case .malformedFrontMatter(let code, _): return code
        case .docNotFound(let code, _): return code
        case .packNotFound(let code, _): return code
        case .docAlreadyExists(let code, _): return code
        case .packAlreadyExists(let code, _): return code
        case .typeMismatch(let code, _, _): return code
        case .schemaValidationFailed(let code, _, _, _, _): return code
        case .invalidPatchMode(let code, _): return code
        case .ioError(let code, _): return code
        case .encodingError(let code): return code
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .malformedInput(_, let message):
            return "Malformed input: \(message)"
        case .malformedFrontMatter(_, let message):
            return "Malformed front matter: \(message)"
        case .docNotFound(_, let uuid):
            return "Document not found: \(uuid)"
        case .packNotFound(_, let name):
            return "Pack not found: \(name)"
        case .docAlreadyExists(_, let uuid):
            return "Document already exists: \(uuid)"
        case .packAlreadyExists(_, let name):
            return "Pack already exists: \(name)"
        case .typeMismatch(_, let docType, let patchType):
            return "Type mismatch: document type '\(docType)' cannot be changed to '\(patchType)'"
        case .schemaValidationFailed(_, let details, _, _, _):
            return "Error from core library: Schema validation failed: \(details)"
        case .invalidPatchMode(_, let mode):
            return "Invalid patch mode: \(mode)"
        case .ioError(_, let message):
            return "I/O error: \(message)"
        case .encodingError(_):
            return "Encoding error"
        }
    }
}

extension AethelError {
    public func toJSON() -> [String: Any] {
        var result: [String: Any] = [
            "code": errorCode,
            "message": getErrorMessage()
        ]
        
        // Add structured data for schema validation errors
        if case .schemaValidationFailed(_, _, let pointer, let expected, let got) = self {
            var dataDict: [String: Any] = [:]
            dataDict["expected"] = expected ?? NSNull()
            dataDict["got"] = got
            dataDict["pointer"] = pointer
            result["data"] = dataDict
        } else {
            result["data"] = NSNull()
        }
        
        return result
    }
    
    private func getErrorMessage() -> String {
        switch self {
        case .malformedInput(_, let message):
            return message
        case .malformedFrontMatter(_, let message):
            return message
        case .docNotFound(_, let uuid):
            return "Document not found: \(uuid)"
        case .packNotFound(_, let name):
            return "Pack not found: \(name)"
        case .docAlreadyExists(_, let uuid):
            return "Document already exists: \(uuid)"
        case .packAlreadyExists(_, let name):
            return "Pack already exists: \(name)"
        case .typeMismatch(_, let docType, let patchType):
            return "Type mismatch: document type '\(docType)' cannot be changed to '\(patchType)'"
        case .schemaValidationFailed(_, let details, _, _, _):
            return "Error from core library: Schema validation failed: \(details)"
        case .invalidPatchMode(_, let mode):
            return "Invalid patch mode: \(mode)"
        case .ioError(_, let message):
            return "I/O error: \(message)"
        case .encodingError(_):
            return "Encoding error"
        }
    }
}