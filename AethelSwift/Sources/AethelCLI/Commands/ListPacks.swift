import Foundation
import ArgumentParser
import AethelCore

struct ListPacks: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List installed packs"
    )
    
    @OptionGroup var globalOptions: GlobalOptions
    
    @Option(name: .long, help: "Output format")
    var output: OutputFormat = .json
    
    func run() throws {
        do {
            let vault = try Vault(at: globalOptions.vaultRoot ?? ".")
            let packDetails = try vault.listPackDetails()
            
            try JSONOutput.writeArray(packDetails, format: output)
        } catch let error as AethelError {
            JSONOutput.writeError(error)
            throw ExitCode(1)
        }
    }
}