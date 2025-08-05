import Foundation

extension Vault {
    public struct TestMode {
        public let now: Date?
        public let uuidSeed: String?
        
        public init(now: Date? = nil, uuidSeed: String? = nil) {
            self.now = now
            self.uuidSeed = uuidSeed
        }
        
        public init(nowString: String?, uuidSeed: String?) {
            self.now = nowString.flatMap { ISO8601DateFormatter().date(from: $0) }
            self.uuidSeed = uuidSeed
        }
        
        public static var current: TestMode {
            let now = ProcessInfo.processInfo.environment["--now"]
                .flatMap { ISO8601DateFormatter().date(from: $0) }
            let uuidSeed = ProcessInfo.processInfo.environment["--uuid-seed"]
            
            return TestMode(now: now, uuidSeed: uuidSeed)
        }
    }
    
    public struct WriteResult: Codable {
        public let uuid: UUID
        public let path: String
        public let committed: Bool
        public let warnings: [String]
        
        public init(uuid: UUID, path: String, committed: Bool, warnings: [String] = []) {
            self.uuid = uuid
            self.path = path
            self.committed = committed
            self.warnings = warnings
        }
    }
    
    public func applyPatch(_ patch: Patch, testMode: TestMode = TestMode()) throws -> WriteResult {
        try patch.validate()
        
        let now = testMode.now ?? Date()
        
        switch patch.mode {
        case .create:
            return try createDoc(patch: patch, testMode: testMode, now: now)
        case .append:
            return try appendDoc(patch: patch, testMode: testMode, now: now)
        case .replaceBody:
            return try replaceBodyDoc(patch: patch, testMode: testMode, now: now)
        case .mergeFrontmatter:
            return try mergeFrontmatterDoc(patch: patch, testMode: testMode, now: now)
        }
    }
    
    private func createDoc(patch: Patch, testMode: TestMode, now: Date) throws -> WriteResult {
        let uuid = generateUUID(testMode: testMode)
        
        guard let type = patch.type else {
            throw AethelError.malformedInput(message: "type field is required for create mode")
        }
        
        if docExists(uuid: uuid) {
            throw AethelError.docAlreadyExists(uuid: uuid)
        }
        
        let frontMatter = patch.frontmatterDict ?? [:]
        let body = patch.body ?? ""
        
        let doc = Doc.createNew(
            uuid: uuid,
            type: type,
            frontMatter: frontMatter,
            body: body,
            now: now
        )
        
        try validateDoc(doc)
        try writeDoc(doc)
        
        let relativePath = "docs/\(uuid.uuidString.lowercased()).md"
        return WriteResult(uuid: uuid, path: "vault/\(relativePath)", committed: true)
    }
    
    private func appendDoc(patch: Patch, testMode: TestMode, now: Date) throws -> WriteResult {
        guard let uuid = patch.uuid else {
            throw AethelError.malformedInput(message: "append mode requires uuid")
        }
        
        var doc: Doc
        
        if docExists(uuid: uuid) {
            doc = try readDoc(uuid: uuid)
        } else {
            // For append mode, we need a type if creating new
            guard let type = patch.type else {
                throw AethelError.malformedInput(message: "type field is required when creating new doc")
            }
            doc = Doc.createNew(uuid: uuid, type: type, frontMatter: [:], body: "", now: now)
        }
        
        var newBody = doc.body
        if let appendBody = patch.body, !appendBody.isEmpty {
            if !newBody.isEmpty {
                newBody += "\n\n"
            }
            newBody += appendBody
        }
        
        let updatedDoc = doc.updated(frontMatter: patch.frontmatterDict, body: newBody, now: now)
        try validateDoc(updatedDoc)
        try writeDoc(updatedDoc)
        
        let relativePath = "docs/\(uuid.uuidString.lowercased()).md"
        return WriteResult(uuid: uuid, path: "vault/\(relativePath)", committed: true)
    }
    
    private func replaceBodyDoc(patch: Patch, testMode: TestMode, now: Date) throws -> WriteResult {
        guard let uuid = patch.uuid else {
            throw AethelError.malformedInput(message: "replace_body mode requires uuid")
        }
        
        guard let newBody = patch.body else {
            throw AethelError.malformedInput(message: "replace_body mode requires body")
        }
        
        var doc: Doc
        
        if docExists(uuid: uuid) {
            doc = try readDoc(uuid: uuid)
        } else {
            guard let type = patch.type else {
                throw AethelError.malformedInput(message: "type field is required when creating new doc")
            }
            doc = Doc.createNew(uuid: uuid, type: type, frontMatter: [:], body: "", now: now)
        }
        
        let updatedDoc = doc.updated(frontMatter: patch.frontmatterDict, body: newBody, now: now)
        try validateDoc(updatedDoc)
        try writeDoc(updatedDoc)
        
        let relativePath = "docs/\(uuid.uuidString.lowercased()).md"
        return WriteResult(uuid: uuid, path: "vault/\(relativePath)", committed: true)
    }
    
    private func mergeFrontmatterDoc(patch: Patch, testMode: TestMode, now: Date) throws -> WriteResult {
        guard let uuid = patch.uuid else {
            throw AethelError.malformedInput(message: "merge_frontmatter mode requires uuid")
        }
        
        var doc: Doc
        
        if docExists(uuid: uuid) {
            doc = try readDoc(uuid: uuid)
            
            // Check for type mismatch if patch specifies a type
            if let patchType = patch.type,
               let existingType = doc.frontMatterDict["type"] as? String,
               patchType != existingType {
                throw AethelError.typeMismatch(docType: existingType, patchType: patchType)
            }
        } else {
            guard let type = patch.type else {
                throw AethelError.malformedInput(message: "type field is required when creating new doc")
            }
            doc = Doc.createNew(uuid: uuid, type: type, frontMatter: [:], body: "", now: now)
        }
        
        let updatedDoc = doc.updated(frontMatter: patch.frontmatterDict, now: now)
        try validateDoc(updatedDoc)
        try writeDoc(updatedDoc)
        
        let relativePath = "docs/\(uuid.uuidString.lowercased()).md"
        return WriteResult(uuid: uuid, path: "vault/\(relativePath)", committed: true)
    }
    
    nonisolated(unsafe) private static var uuidCounter: UInt64 = 0
    
    private func generateUUID(testMode: TestMode) -> UUID {
        if let seedString = testMode.uuidSeed, let seed = UInt64(seedString, radix: 16) {
            // Match Rust implementation exactly
            let counter = Self.uuidCounter
            Self.uuidCounter += 1
            
            let value = seed.addingReportingOverflow(counter).partialValue
            
            // Create deterministic UUID v4 matching Rust logic
            let bytes: [UInt8] = [
                UInt8((value >> 56) & 0xFF),
                UInt8((value >> 48) & 0xFF), 
                UInt8((value >> 40) & 0xFF),
                UInt8((value >> 32) & 0xFF),
                UInt8((value >> 24) & 0xFF),
                UInt8((value >> 16) & 0xFF),
                0x40 | UInt8((value >> 8) & 0x0F), // Version 4
                UInt8(value & 0xFF),
                0x80 | UInt8((seed >> 56) & 0x3F), // Variant
                UInt8((seed >> 48) & 0xFF),
                UInt8((seed >> 40) & 0xFF),
                UInt8((seed >> 32) & 0xFF),
                UInt8((seed >> 24) & 0xFF),
                UInt8((seed >> 16) & 0xFF),
                UInt8((seed >> 8) & 0xFF),
                UInt8(seed & 0xFF)
            ]
            
            return UUID(uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
        }
        
        return UUID()
    }
}