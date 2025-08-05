import Foundation
import ArgumentParser
import AethelCore

struct GlobalOptions: ParsableArguments {
    @Option(name: .long, help: "Path to vault root (defaults to current directory)")
    var vaultRoot: String?
    
    @Option(name: .long, help: "Override current timestamp (only with AETHEL_TEST_MODE=1)")
    var now: String?
    
    @Option(name: .long, help: "UUID generation seed for reproducible UUIDs (only with AETHEL_TEST_MODE=1)")
    var uuidSeed: String?
    
    @Flag(name: .long, help: "Disable git operations (only with AETHEL_TEST_MODE=1)")
    var git: Bool = false
}

struct AethelCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aethel",
        abstract: "Aethel document management system",
        subcommands: [
            Init.self,
            Write.self,
            Read.self,
            Check.self,
            ListPacks.self,
            AddPack.self,
            RemovePack.self
        ]
    )
}

AethelCLI.main()