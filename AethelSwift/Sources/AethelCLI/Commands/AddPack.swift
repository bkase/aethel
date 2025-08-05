import Foundation
import ArgumentParser
import AethelCore

struct AddPack: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a pack to the vault"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Argument(help: "Path to pack directory")
    var path: String
    
    @Option(name: .long, help: "Output format")
    var output: OutputFormat = .json
    
    func run() throws {
        do {
            let vault = try Vault(at: globalOptions.vaultRoot ?? ".")
            
            // Read the pack first to get its name
            let packJsonPath = URL(fileURLWithPath: path).appendingPathComponent("pack.json")
            let packData = try Data(contentsOf: packJsonPath)
            let pack = try JSONDecoder().decode(Pack.self, from: packData)
            
            // Add pack using the name and version from pack.json
            let packNameWithVersion = "\(pack.name)@\(pack.version)"
            try vault.addPack(from: path, name: packNameWithVersion)
            
            // Return the pack details
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
            try JSONOutput.writeDictionary(packDict, format: output)
        } catch let error as AethelError {
            JSONOutput.writeError(error)
            throw ExitCode(1)
        } catch let decodingError as DecodingError {
            let aethelError = AethelError.malformedInput(message: "Failed to decode pack.json: \(decodingError.localizedDescription)")
            JSONOutput.writeError(aethelError)
            throw ExitCode(1)
        } catch {
            let aethelError = AethelError.ioError(message: "Unexpected error: \(error.localizedDescription)")
            JSONOutput.writeError(aethelError)
            throw ExitCode(1)
        }
    }
}