import Foundation

public struct Vault {
    private let rootURL: URL
    
    public init(at path: String) throws {
        let expandedPath = PathHelpers.expandPath(path)
        self.rootURL = URL(fileURLWithPath: expandedPath)
        try validate()
    }
    
    private func validate() throws {
        // For now, just check if we can work with the vault
        // Vault validation should be minimal - just check it's a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) && isDirectory.boolValue else {
            throw AethelError.ioError(message: "Not a valid vault: directory not found")
        }
    }
    
    public func readDoc(uuid: UUID) throws -> Doc {
        let docPath = PathHelpers.docPath(for: uuid, in: rootURL.path)
        
        guard FileManager.default.fileExists(atPath: docPath.path) else {
            throw AethelError.docNotFound(uuid: uuid)
        }
        
        do {
            let content = try String(contentsOf: docPath)
            return try Doc(from: content)
        } catch let error as AethelError {
            throw error
        } catch {
            throw AethelError.ioError(message: error.localizedDescription)
        }
    }
    
    public func writeDoc(_ doc: Doc) throws {
        let docPath = PathHelpers.docPath(for: doc.uuid, in: rootURL.path)
        let content = doc.toMarkdown()
        try AtomicFileWriter.write(content, to: docPath)
    }
    
    public func docExists(uuid: UUID) -> Bool {
        let docPath = PathHelpers.docPath(for: uuid, in: rootURL.path)
        return FileManager.default.fileExists(atPath: docPath.path)
    }
    
    public func listDocs() throws -> [UUID] {
        let docsDir = rootURL.appendingPathComponent("docs")
        
        guard FileManager.default.fileExists(atPath: docsDir.path) else {
            return []
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: docsDir.path)
            return files.compactMap { filename in
                guard filename.hasSuffix(".md") else { return nil }
                let uuidString = String(filename.dropLast(3))
                return UUID(uuidString: uuidString)
            }
        } catch {
            throw AethelError.ioError(message: error.localizedDescription)
        }
    }
    
    public func addPack(from path: String, name: String) throws {
        let expandedPath = PathHelpers.expandPath(path)
        let sourcePath = URL(fileURLWithPath: expandedPath)
        let packPath = PathHelpers.packPath(for: name, in: rootURL.path)
        
        // Check if source exists
        if !FileManager.default.fileExists(atPath: sourcePath.path) {
            throw AethelError.ioError(message: "Source path does not exist: \(sourcePath.path)")
        }
        
        if FileManager.default.fileExists(atPath: packPath.path) {
            throw AethelError.packAlreadyExists(name: name)
        }
        
        do {
            try FileManager.default.copyItem(at: sourcePath, to: packPath)
        } catch {
            throw AethelError.ioError(message: "Copy failed from \(sourcePath.path) to \(packPath.path): \(error.localizedDescription)")
        }
    }
    
    public func removePack(name: String) throws {
        let packPath = PathHelpers.packPath(for: name, in: rootURL.path)
        
        guard FileManager.default.fileExists(atPath: packPath.path) else {
            throw AethelError.packNotFound(name: name)
        }
        
        do {
            try FileManager.default.removeItem(at: packPath)
        } catch {
            throw AethelError.ioError(message: error.localizedDescription)
        }
    }
    
    public func listPacks() throws -> [String] {
        let packsDir = rootURL.appendingPathComponent("packs")
        
        guard FileManager.default.fileExists(atPath: packsDir.path) else {
            return []
        }
        
        do {
            return try FileManager.default.contentsOfDirectory(atPath: packsDir.path)
                .filter { !$0.hasPrefix(".") }
        } catch {
            throw AethelError.ioError(message: error.localizedDescription)
        }
    }
    
    public func listPackDetails() throws -> [[String: Any]] {
        let packNames = try listPacks()
        var packDetails: [[String: Any]] = []
        
        for packName in packNames {
            do {
                let pack = try readPack(name: packName)
                let packDict: [String: Any] = [
                    "name": pack.name,
                    "version": pack.version,
                    "protocolVersion": pack.protocolVersion,
                    "types": pack.types.map { type in
                        [
                            "id": type.id,
                            "version": type.version
                        ]
                    }
                ]
                packDetails.append(packDict)
            } catch {
                // Skip packs that can't be read
                continue
            }
        }
        
        return packDetails
    }
    
    public func readPack(name: String) throws -> Pack {
        let packPath = PathHelpers.packPath(for: name, in: rootURL.path)
        let packJsonPath = packPath.appendingPathComponent("pack.json")
        
        guard FileManager.default.fileExists(atPath: packJsonPath.path) else {
            throw AethelError.packNotFound(name: name)
        }
        
        do {
            let data = try Data(contentsOf: packJsonPath)
            return try JSONDecoder().decode(Pack.self, from: data)
        } catch let error as AethelError {
            throw error
        } catch {
            throw AethelError.ioError(message: error.localizedDescription)
        }
    }
    
    public static func initialize(at path: String) throws {
        let expandedPath = PathHelpers.expandPath(path)
        let vaultURL = URL(fileURLWithPath: expandedPath)
        
        let aethelDir = vaultURL.appendingPathComponent(".aethel")
        let docsDir = vaultURL.appendingPathComponent("docs")
        let packsDir = vaultURL.appendingPathComponent("packs")
        
        do {
            try FileManager.default.createDirectory(at: aethelDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: packsDir, withIntermediateDirectories: true)
        } catch {
            throw AethelError.ioError(message: error.localizedDescription)
        }
    }
    
    internal func validateDoc(_ doc: Doc) throws {
        guard let typeString = doc.frontMatterDict["type"] as? String else {
            throw AethelError.malformedInput(message: "Document missing type field")
        }
        
        // Load the schema for this document type
        let schema = try loadSchemaForType(typeString)
        
        // Validate the entire frontmatter against the schema
        let validator = JSONSchemaValidator(schema: schema)
        try validator.validate(doc.frontMatterDict)
    }
    
    private func loadSchemaForType(_ typeString: String) throws -> JSONSchema {
        // Type format is like "journal.morning" where "journal" is the pack and "morning" is the type
        let components = typeString.split(separator: ".")
        guard components.count == 2 else {
            throw AethelError.schemaValidationFailed(details: "Invalid type format: \(typeString)")
        }
        
        let packName = String(components[0])
        let typeName = String(components[1])
        
        // Find the pack with this name
        let packs = try listPacks()
        let matchingPack = packs.first { packNameWithVersion in
            return packNameWithVersion.hasPrefix("\(packName)@")
        }
        
        guard let packNameWithVersion = matchingPack else {
            throw AethelError.packNotFound(name: packName)
        }
        
        // Load the schema file
        let packPath = PathHelpers.packPath(for: packNameWithVersion, in: rootURL.path)
        let schemaPath = packPath.appendingPathComponent("types").appendingPathComponent("\(typeName).schema.json")
        
        guard FileManager.default.fileExists(atPath: schemaPath.path) else {
            throw AethelError.schemaValidationFailed(details: "Schema file not found for type \(typeString)")
        }
        
        do {
            let data = try Data(contentsOf: schemaPath)
            return try JSONDecoder().decode(JSONSchema.self, from: data)
        } catch {
            throw AethelError.schemaValidationFailed(details: "Failed to load schema: \(error.localizedDescription)")
        }
    }
}