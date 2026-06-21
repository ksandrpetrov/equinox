import Foundation

/// ISO and day-boundary date parsing shared by `EventKitBridge` and MCP analytics.
enum BridgeDateParsing {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func parseDateBoundary(_ value: String, endOfDay: Bool) -> Date? {
        if value.count == 10, let day = dayFormatter.date(from: value) {
            return boundaryDate(for: day, endOfDay: endOfDay)
        }
        if let instant = parseInstant(value) {
            return instant
        }
        guard let day = dayFormatter.date(from: value) else { return nil }
        return boundaryDate(for: day, endOfDay: endOfDay)
    }

    static func parseInstant(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let date = isoFormatter.date(from: value) {
            return date
        }
        if let date = isoFormatterNoFraction.date(from: value) {
            return date
        }
        return dayFormatter.date(from: value)
    }

    static func formatInstant(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    private static func boundaryDate(for day: Date, endOfDay: Bool) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        if endOfDay {
            components.hour = 23
            components.minute = 59
            components.second = 59
        } else {
            components.hour = 0
            components.minute = 0
            components.second = 0
        }
        return Calendar.current.date(from: components)
    }
}
