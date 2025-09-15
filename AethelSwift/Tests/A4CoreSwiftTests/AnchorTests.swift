import XCTest
@testable import A4CoreSwift

final class AnchorTests: XCTestCase {
    func testValidAnchorParsing() throws {
        let token = try AnchorToken(parse: "focus-0930")
        XCTAssertEqual(token.prefix, "focus")
        XCTAssertEqual(token.hhmm, "0930")
        XCTAssertNil(token.suffix)
        XCTAssertEqual(token.marker(), "^focus-0930")
    }

    func testAnchorWithSuffix() throws {
        let token = try AnchorToken(parse: "jrnl-0812__iphone")
        XCTAssertEqual(token.prefix, "jrnl")
        XCTAssertEqual(token.hhmm, "0812")
        XCTAssertEqual(token.suffix, "iphone")
        XCTAssertEqual(token.marker(), "^jrnl-0812__iphone")
    }

    func testInvalidAnchorUppercase() {
        XCTAssertThrowsError(try AnchorToken(parse: "FOCUS-0930")) { error in
            guard case A4Error.invalidAnchor = error else {
                XCTFail("Expected invalidAnchor error")
                return
            }
        }
    }

    func testInvalidAnchorNoPrefix() {
        XCTAssertThrowsError(try AnchorToken(parse: "0930")) { error in
            guard case A4Error.invalidAnchor = error else {
                XCTFail("Expected invalidAnchor error")
                return
            }
        }
    }

    func testInvalidAnchorBadTime() {
        XCTAssertThrowsError(try AnchorToken(parse: "focus-2500")) { error in
            guard case A4Error.invalidAnchor = error else {
                XCTFail("Expected invalidAnchor error")
                return
            }
        }
    }

    func testInvalidAnchorDoubleSuffix() {
        XCTAssertThrowsError(try AnchorToken(parse: "bad__sfx__more")) { error in
            guard case A4Error.invalidAnchor = error else {
                XCTFail("Expected invalidAnchor error")
                return
            }
        }
    }

    func testValidTimeRanges() throws {
        _ = try AnchorToken(parse: "test-0000")
        _ = try AnchorToken(parse: "test-2359")
        _ = try AnchorToken(parse: "test-1230")
    }

    func testInvalidTimeRanges() {
        XCTAssertThrowsError(try AnchorToken(parse: "test-2400"))
        XCTAssertThrowsError(try AnchorToken(parse: "test-1260"))
        XCTAssertThrowsError(try AnchorToken(parse: "test-9999"))
    }

    func testPrefixLengthBounds() throws {
        _ = try AnchorToken(parse: "ab-1200")
        _ = try AnchorToken(parse: "a234567890123456789012345-1200")  // 25 chars

        XCTAssertThrowsError(try AnchorToken(parse: "a-1200"))
        XCTAssertThrowsError(try AnchorToken(parse: "a23456789012345678901234567-1200"))  // 26 chars
    }
}