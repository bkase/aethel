import Foundation
import ArgumentParser
import AethelCore

struct RemovePack: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove a pack from the vault"
    )
    
    @Option(name: .long, help: "Vault root directory")
    var vaultRoot: String?
    
    @Flag(name: .long, help: "Remove pack")
    var pack: Bool = false
    
    @Argument(help: "Pack name")
    var name: String
    
    @Option(name: .long, help: "Output format")
    var output: OutputFormat = .json
    
    func run() throws {
        do {
            let vault = try Vault(at: vaultRoot ?? ".")
            try vault.removePack(name: name)
            
            let result = PackOperationResponse(success: true, pack: name)
            try JSONOutput.write(result, format: output)
        } catch let error as AethelError {
            JSONOutput.writeError(error)
            throw ExitCode(1)
        }
    }
}