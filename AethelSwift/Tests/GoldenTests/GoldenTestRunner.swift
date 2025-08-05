import Testing
import Foundation
import XCTest
@testable import AethelCore

@Suite("Golden Tests")
struct GoldenTests {
    let testCasesPath = URL(fileURLWithPath: "../../tests/cases")
    
    @Test("Golden Test Suite - Load Cases")
    func loadAndRunGoldenTests() async throws {
        let testCases = try Self.loadTestCases()
        
        if testCases.isEmpty {
            throw XCTSkip("No golden test cases found")
        }
        
        for testCase in testCases {
            try await runSingleGoldenTest(testCase)
        }
    }
    
    func runSingleGoldenTest(_ testCase: TestCase) async throws {
        // Create temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Copy vault.before
        let vaultPath = tempDir.appendingPathComponent("vault")
        try DirectoryComparison.copyDirectory(from: testCase.vaultBefore, to: vaultPath)
        
        // Run CLI command
        let process = Process()
        
        // Find the aethel binary
        let executableURL: URL
        if let buildPath = ProcessInfo.processInfo.environment["BUILD_PATH"] {
            executableURL = URL(fileURLWithPath: buildPath).appendingPathComponent("aethel")
        } else {
            executableURL = URL(fileURLWithPath: ".build/debug/aethel")
        }
        
        process.executableURL = executableURL
        process.currentDirectoryURL = tempDir
        
        var args = ["--vault-root", vaultPath.path]
        args.append(contentsOf: testCase.cliArgs)
        
        // Add test mode arguments
        if let now = testCase.envVars["--now"] {
            args.append(contentsOf: ["--now", now])
        }
        if let uuidSeed = testCase.envVars["--uuid-seed"] {
            args.append(contentsOf: ["--uuid-seed", uuidSeed])
        }
        
        process.arguments = args
        
        var environment = ProcessInfo.processInfo.environment
        environment["AETHEL_TEST_MODE"] = "1"
        process.environment = environment
        
        // Setup pipes for I/O
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Write input if needed
        if let input = testCase.inputJSON {
            let inputData = input.data(using: .utf8)!
            inputPipe.fileHandleForWriting.write(inputData)
            inputPipe.fileHandleForWriting.closeFile()
        } else {
            inputPipe.fileHandleForWriting.closeFile()
        }
        
        // Run process
        try process.run()
        process.waitUntilExit()
        
        // Verify results
        let exitCode = process.terminationStatus
        #expect(exitCode == testCase.expectExit, "Exit code mismatch: expected \(testCase.expectExit), got \(exitCode)")
        
        // Check output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        switch testCase.expectOutput {
        case .json(let expected):
            if !outputData.isEmpty {
                let actual = try JSONSerialization.jsonObject(with: outputData)
                try OutputNormalization.compareJSON(expected, actual)
            } else if !expected.isEmpty {
                throw TestError.invalidTestCase("Expected JSON output but got empty output")
            }
            
        case .markdown(let expected):
            try OutputNormalization.compareMarkdown(expected, output)
        }
        
        // Verify vault.after if present
        if let vaultAfter = testCase.vaultAfter {
            try DirectoryComparison.compareDirectories(vaultPath, vaultAfter)
        }
    }
    
    static func loadTestCases() throws -> [TestCase] {
        let casesDir = URL(fileURLWithPath: "../../tests/cases")
        
        guard FileManager.default.fileExists(atPath: casesDir.path) else {
            // If test cases don't exist, return empty array
            return []
        }
        
        let entries = try FileManager.default.contentsOfDirectory(
            at: casesDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        
        return try entries
            .filter { url in
                let values = try url.resourceValues(forKeys: [.isDirectoryKey])
                return values.isDirectory == true
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try TestCase(from: $0) }
    }
}