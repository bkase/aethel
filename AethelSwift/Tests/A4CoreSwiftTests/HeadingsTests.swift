import XCTest
@testable import A4CoreSwift

final class HeadingsTests: XCTestCase {
    func testInsertMissingH2() throws {
        let input = "Some content".data(using: .utf8)!
        let result = try Headings.ensureH2(textBytes: input, heading: "Journal")

        let resultString = String(data: result, encoding: .utf8)!
        XCTAssertTrue(resultString.contains("\n## Journal\n\n"))
    }

    func testNoDoubleH2() throws {
        let input = "## Journal\nContent".data(using: .utf8)!
        let result = try Headings.ensureH2(textBytes: input, heading: "Journal")

        XCTAssertEqual(result, input)
    }

    func testCaseInsensitiveH2Match() throws {
        let input = "## journal\nContent".data(using: .utf8)!
        let result = try Headings.ensureH2(textBytes: input, heading: "Journal")

        XCTAssertEqual(result, input)
    }

    func testH2WithExistingH1() throws {
        let input = "# Title\n\nContent".data(using: .utf8)!
        let result = try Headings.ensureH2(textBytes: input, heading: "Journal")

        let resultString = String(data: result, encoding: .utf8)!
        XCTAssertTrue(resultString.contains("# Title"))
        XCTAssertTrue(resultString.contains("\n## Journal\n\n"))
    }

    func testEmptyInput() throws {
        let input = Data()
        let result = try Headings.ensureH2(textBytes: input, heading: "Journal")

        let resultString = String(data: result, encoding: .utf8)!
        XCTAssertEqual(resultString, "## Journal\n\n")
    }

    func testTrailingNewlineHandling() throws {
        let input = "Content\n".data(using: .utf8)!
        let result = try Headings.ensureH2(textBytes: input, heading: "Journal")

        let resultString = String(data: result, encoding: .utf8)!
        XCTAssertTrue(resultString.hasPrefix("Content\n"))
        XCTAssertTrue(resultString.contains("\n## Journal\n\n"))
    }
}