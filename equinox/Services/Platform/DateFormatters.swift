import Foundation

enum EquinoxFormatters {
    private static let cacheLock = NSLock()
    private nonisolated(unsafe) static var cachedLocaleIdentifier: String?
    private nonisolated(unsafe) static var cachedTimeZoneIdentifier: String?
    private nonisolated(unsafe) static var formatters: [String: DateFormatter] = [:]

    static var appLocale: Locale {
        Locale.autoupdatingCurrent
    }

    static func formatter(
        key: String,
        configure: (DateFormatter) -> Void
    ) -> DateFormatter {
        let localeID = appLocale.identifier
        let timeZone = TimeZone.autoupdatingCurrent
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedLocaleIdentifier != localeID || cachedTimeZoneIdentifier != timeZone.identifier {
            formatters.removeAll()
            cachedLocaleIdentifier = localeID
            cachedTimeZoneIdentifier = timeZone.identifier
        }

        if let existing = formatters[key] {
            return existing
        }

        let formatter = makeFormatter(
            locale: appLocale,
            timeZone: timeZone,
            configure: configure
        )
        formatters[key] = formatter
        return formatter
    }

    static func makeFormatter(
        locale: Locale,
        timeZone: TimeZone,
        configure: (DateFormatter) -> Void
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar.equinoxGregorian(locale: locale, timeZone: timeZone)
        formatter.timeZone = timeZone
        configure(formatter)
        return formatter
    }

    static func timeRange(from start: Date, to end: Date) -> String {
        "\(shortTime(start)) – \(shortTime(end))"
    }

    static func shortTime(_ date: Date) -> String {
        formatter(key: "time.short") { $0.timeStyle = .short; $0.dateStyle = .none }
            .string(from: date)
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

    static func weekdaySymbols() -> [String] {
        formatter(key: "weekday.veryShort") { _ in }.veryShortWeekdaySymbols
    }

    static func relativeTime(until eventStart: Date, from now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> String? {
        guard calendar.isDate(eventStart, inSameDayAs: now) else { return nil }
        if eventStart <= now {
            return nil
        }
        let interval = eventStart.timeIntervalSince(now)
        let minutes = max(1, Int(ceil(interval / 60)))
        if interval < 60 * 60 {
            return String(format: String(localized: "in %lld min", comment: "Relative event time"), minutes)
        }
        let hours = minutes / 60
        return String(format: String(localized: "in %lld h", comment: "Relative event time hours"), hours)
    }

    static func relativeTimeDuringEvent() -> String {
        String(localized: "Now", comment: "Event happening now")
    }

    static func eventCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "%lld events", comment: "Event count"),
            Int64(count)
        )
    }
}
