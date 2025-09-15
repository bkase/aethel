import XCTest
@testable import A4CoreSwift

final class DatesTests: XCTestCase {
    func testUtcDayConversion() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        let date = dateFormatter.date(from: "2025-03-15 14:30:00")!
        let utcDay = Dates.utcDay(from: date)

        XCTAssertEqual(utcDay.year, 2025)
        XCTAssertEqual(utcDay.month, 3)
        XCTAssertEqual(utcDay.day, 15)
    }

    func testDailyPathComponents() {
        let day = UtcDay(year: 2025, month: 3, day: 5)
        let (year, yearMonth, filename) = Dates.dailyPathComponents(for: day)

        XCTAssertEqual(year, "2025")
        XCTAssertEqual(yearMonth, "2025-03")
        XCTAssertEqual(filename, "2025-03-05.md")
    }

    func testDailyPathComponentsPadding() {
        let day = UtcDay(year: 2025, month: 1, day: 9)
        let (year, yearMonth, filename) = Dates.dailyPathComponents(for: day)

        XCTAssertEqual(year, "2025")
        XCTAssertEqual(yearMonth, "2025-01")
        XCTAssertEqual(filename, "2025-01-09.md")
    }

    func testLocalHHMM() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current

        let date = dateFormatter.date(from: "2025-03-15 09:30:00")!
        let hhmm = Dates.localHHMM(from: date)

        XCTAssertEqual(hhmm, "0930")
    }

    func testLocalHHMMPadding() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current

        let date = dateFormatter.date(from: "2025-03-15 00:05:00")!
        let hhmm = Dates.localHHMM(from: date)

        XCTAssertEqual(hhmm, "0005")
    }

    func testSystemDateProvider() {
        let provider = SystemDateProvider()
        let now = provider.now()

        XCTAssertTrue(now.timeIntervalSinceNow < 1.0)
    }
}