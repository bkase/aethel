import Foundation
import ArgumentParser
import AethelCore

struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Initialize a new Aethel vault"
    )
    
    @Argument(help: "Path to initialize vault (default: current directory)")
    var path: String = "."
    
    @Option(name: .long, help: "Output format")
    var output: OutputFormat = .json
    
    func run() throws {
        do {
            try Vault.initialize(at: path)
            
            let result = InitResponse(success: true, path: PathHelpers.expandPath(path))
            try JSONOutput.write(result, format: output)
        } catch let error as AethelError {
            JSONOutput.writeError(error)
            throw ExitCode(1)
        }
    }
}