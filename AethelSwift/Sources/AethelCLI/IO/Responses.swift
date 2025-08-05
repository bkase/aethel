import Foundation

public struct InitResponse: Codable {
    public let success: Bool
    public let path: String
    
    public init(success: Bool, path: String) {
        self.success = success
        self.path = path
    }
}

public struct CheckResponse: Codable {
    public let valid: Bool
    public let uuid: String
    
    public init(valid: Bool, uuid: String) {
        self.valid = valid
        self.uuid = uuid
    }
}

public struct ListPacksResponse: Codable {
    public let packs: [String]
    
    public init(packs: [String]) {
        self.packs = packs
    }
}

public struct PackOperationResponse: Codable {
    public let success: Bool
    public let pack: String
    public let path: String?
    
    public init(success: Bool, pack: String, path: String? = nil) {
        self.success = success
        self.pack = pack
        self.path = path
    }
}