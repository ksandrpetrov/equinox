import Foundation

enum EquinoxFormatters {
    private static let cacheLock = NSLock()
    private static var cachedLocaleIdentifier: String?
    private static var formatters: [String: DateFormatter] = [:]

    static var appLocale: Locale {
        Locale.autoupdatingCurrent
    }

    static func formatter(
        key: String,
        configure: (DateFormatter) -> Void
    ) -> DateFormatter {
        let localeID = appLocale.identifier
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedLocaleIdentifier != localeID {
            formatters.removeAll()
            cachedLocaleIdentifier = localeID
        }

        if let existing = formatters[key] {
            return existing
        }

        let formatter = DateFormatter()
        formatter.locale = appLocale
        configure(formatter)
        formatters[key] = formatter
        return formatter
    }

    static func timeRange(from start: Date, to end: Date) -> String {
        let formatter = formatter(key: "time.short") { $0.timeStyle = .short; $0.dateStyle = .none }
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    static func mediumDateTime(from start: Date, to end: Date) -> String {
        let formatter = formatter(key: "datetime.medium") {
            $0.dateStyle = .medium
            $0.timeStyle = .short
        }
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    static func agendaHeader(_ date: Date) -> String {
        let formatter = formatter(key: "agenda.header") { $0.setLocalizedDateFormatFromTemplate("MMMd") }
        return formatter.string(from: date)
    }

    static func shortWeekday(_ date: Date) -> String {
        let formatter = formatter(key: "weekday.short") { $0.dateFormat = "EEE" }
        return formatter.string(from: date)
    }

    static func dayMonth(_ date: Date) -> String {
        let formatter = formatter(key: "day.month") { $0.dateFormat = "d MMMM" }
        return formatter.string(from: date)
    }

    static func weekdaySymbols() -> [String] {
        let formatter = formatter(key: "weekday.veryShort") { _ in }
        return formatter.veryShortWeekdaySymbols
            ?? formatter.shortWeekdaySymbols
            ?? ["В", "П", "В", "С", "Ч", "П", "С"]
    }

    static func relativeTime(until eventStart: Date, from now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> String? {
        guard calendar.isDateInToday(eventStart) else { return nil }
        if eventStart <= now {
            return nil
        }
        let minutes = Int(eventStart.timeIntervalSince(now) / 60)
        if minutes < 60 {
            return String(format: String(localized: "in %lld min", comment: "Relative event time"), minutes)
        }
        let hours = minutes / 60
        return String(format: String(localized: "in %lld h", comment: "Relative event time hours"), hours)
    }

    static func relativeTimeDuringEvent(from now: Date = Date()) -> String {
        String(localized: "Now", comment: "Event happening now")
    }
}

var appLocale: Locale { EquinoxFormatters.appLocale }
