import Foundation

public struct UtcDay: Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

public protocol DateProvider: Sendable {
    func now() -> Date
}

public struct SystemDateProvider: DateProvider {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

public enum Dates {
    public static func utcDay(from date: Date) -> UtcDay {
        let calendar = Calendar(identifier: .gregorian)
        let utcTimeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents(
            in: utcTimeZone,
            from: date
        )

        return UtcDay(
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0
        )
    }

    public static func dailyPathComponents(for day: UtcDay) -> (String, String, String) {
        let year = String(format: "%04d", day.year)
        let yearMonth = String(format: "%04d-%02d", day.year, day.month)
        let filename = String(format: "%04d-%02d-%02d.md", day.year, day.month, day.day)

        return (year, yearMonth, filename)
    }

    public static func localHHMM(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}