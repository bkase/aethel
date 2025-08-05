import Foundation

enum TestError: Error {
    case missingExpectedOutput
    case invalidTestCase(String)
}

struct TestCase {
    let name: String
    let cliArgs: [String]
    let envVars: [String: String]
    let inputJSON: String?
    let expectExit: Int32
    let expectOutput: ExpectedOutput
    let vaultBefore: URL
    let vaultAfter: URL?
    
    enum ExpectedOutput {
        case json([String: Any])
        case markdown(String)
    }
    
    init(from caseDir: URL) throws {
        self.name = caseDir.lastPathComponent
        
        // Load CLI args
        let argsPath = caseDir.appendingPathComponent("cli-args.txt")
        let argsContent = try String(contentsOf: argsPath)
        self.cliArgs = argsContent.split(separator: " ").map(String.init)
        
        // Load env vars
        let envPath = caseDir.appendingPathComponent("env.json")
        if FileManager.default.fileExists(atPath: envPath.path) {
            let envData = try Data(contentsOf: envPath)
            self.envVars = try JSONDecoder().decode([String: String].self, from: envData)
        } else {
            self.envVars = [:]
        }
        
        // Load input
        let inputPath = caseDir.appendingPathComponent("input.json")
        if FileManager.default.fileExists(atPath: inputPath.path) {
            self.inputJSON = try String(contentsOf: inputPath)
        } else {
            self.inputJSON = nil
        }
        
        // Load expected exit code
        let exitPath = caseDir.appendingPathComponent("expect.exit.txt")
        let exitString = try String(contentsOf: exitPath).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let exitCode = Int32(exitString) else {
            throw TestError.invalidTestCase("Invalid exit code: \(exitString)")
        }
        self.expectExit = exitCode
        
        // Load expected output
        let jsonOutputPath = caseDir.appendingPathComponent("expect.stdout.json")
        let mdOutputPath = caseDir.appendingPathComponent("expect.stdout.md")
        
        if FileManager.default.fileExists(atPath: jsonOutputPath.path) {
            let data = try Data(contentsOf: jsonOutputPath)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            self.expectOutput = .json(json)
        } else if FileManager.default.fileExists(atPath: mdOutputPath.path) {
            let markdown = try String(contentsOf: mdOutputPath)
            self.expectOutput = .markdown(markdown)
        } else {
            throw TestError.missingExpectedOutput
        }
        
        // Load vault paths
        self.vaultBefore = caseDir.appendingPathComponent("vault.before")
        let vaultAfterPath = caseDir.appendingPathComponent("vault.after")
        self.vaultAfter = FileManager.default.fileExists(atPath: vaultAfterPath.path) ? vaultAfterPath : nil
    }
}