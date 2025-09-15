import XCTest
@testable import A4CoreSwift

final class NotesTests: XCTestCase {
    func testNoFrontMatter() {
        let input = "# Title\n\nContent".data(using: .utf8)!
        let result = Notes.splitFrontMatter(input)

        guard case .none(let body) = result else {
            XCTFail("Expected no front matter")
            return
        }

        XCTAssertEqual(body, input)
        XCTAssertNil(result.header)
    }

    func testSimpleFrontMatter() {
        let input = """
---
title: Test
date: 2025-01-01
---
# Content
""".data(using: .utf8)!

        let result = Notes.splitFrontMatter(input)

        guard case .present(let header, let body) = result else {
            XCTFail("Expected front matter present")
            return
        }

        let headerString = String(data: header, encoding: .utf8)!
        let bodyString = String(data: body, encoding: .utf8)!

        XCTAssertTrue(headerString.contains("title: Test"))
        XCTAssertTrue(headerString.contains("date: 2025-01-01"))
        XCTAssertEqual(bodyString, "# Content")
    }

    func testJoinWithoutHeader() {
        let body = "# Content\n".data(using: .utf8)!
        let result = Notes.joinFrontMatter(header: nil, body: body)

        XCTAssertEqual(result, body)
    }

    func testJoinWithHeader() {
        let header = "title: Test\ndate: 2025-01-01".data(using: .utf8)!
        let body = "# Content\n".data(using: .utf8)!
        let result = Notes.joinFrontMatter(header: header, body: body)

        let resultString = String(data: result, encoding: .utf8)!
        XCTAssertTrue(resultString.hasPrefix("---\n"))
        XCTAssertTrue(resultString.contains("title: Test"))
        XCTAssertTrue(resultString.contains("---\n# Content"))
    }

    func testFrontMatterPreservation() {
        let original = """
---
title: Test
tags: [a, b]
---
Content
""".data(using: .utf8)!

        let split = Notes.splitFrontMatter(original)
        let rejoined = Notes.joinFrontMatter(header: split.header, body: split.body)

        XCTAssertEqual(original, rejoined)
    }

    func testMultiLineFrontMatter() {
        let input = """
---
title: |
  Multi
  Line
  Title
date: 2025-01-01
---
Content
""".data(using: .utf8)!

        let result = Notes.splitFrontMatter(input)

        guard case .present(let header, let body) = result else {
            XCTFail("Expected front matter present")
            return
        }

        let headerString = String(data: header, encoding: .utf8)!
        XCTAssertTrue(headerString.contains("Multi"))
        XCTAssertTrue(headerString.contains("Line"))
        XCTAssertTrue(headerString.contains("Title"))
    }
}