import Foundation
import ArgumentParser

public enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
    case json
    case markdown = "md"
    
    public static var allValueStrings: [String] {
        return allCases.map { $0.rawValue }
    }
}