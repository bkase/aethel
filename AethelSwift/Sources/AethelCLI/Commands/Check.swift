import Foundation
import ArgumentParser
import AethelCore

struct Check: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Validate a document"
    )
    
    @Option(name: .long, help: "Vault root directory")
    var vaultRoot: String?
    
    @Argument(help: "Document UUID")
    var uuid: String
    
    @Option(name: .long, help: "Output format")
    var output: OutputFormat = .json
    
    func run() throws {
        do {
            guard let docUUID = UUID(uuidString: uuid) else {
                throw AethelError.malformedInput(message: "Invalid UUID format")
            }
            
            let vault = try Vault(at: vaultRoot ?? ".")
            let doc = try vault.readDoc(uuid: docUUID)
            
            let result = CheckResponse(valid: true, uuid: doc.uuid.uuidString)
            try JSONOutput.write(result, format: output)
        } catch let error as AethelError {
            JSONOutput.writeError(error)
            throw ExitCode(1)
        }
    }
}