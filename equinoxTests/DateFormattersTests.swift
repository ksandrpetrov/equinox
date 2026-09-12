import XCTest
@testable import EquinoxKit

final class DateFormattersTests: XCTestCase {
    func testLocaleNotificationCanInvalidateFormattersWithoutChangingLocaleIdentifier() {
        let first = EquinoxFormatters.formatter(key: "test.locale-overrides") { $0.dateFormat = "HH" }
        EquinoxFormatters.invalidateCache()
        let second = EquinoxFormatters.formatter(key: "test.locale-overrides") { $0.dateFormat = "hh" }
        XCTAssertFalse(first === second)
        XCTAssertEqual(second.dateFormat, "hh")
    }

    func testRelativeTimeNeverShowsZeroMinutes() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let eventStart = now.addingTimeInterval(15)
        let expected = String(
            format: String(localized: "in %lld min", bundle: .equinox, comment: "Relative event time"),
            1
        )

        XCTAssertEqual(
            EquinoxFormatters.relativeTime(until: eventStart, from: now),
            expected
        )
    }

    func testCachedFormattersUseAutoupdatingSystemTimeZone() {
        let formatter = EquinoxFormatters.formatter(key: "test.autoupdating-time-zone") {
            $0.timeStyle = .short
        }

        XCTAssertEqual(formatter.timeZone.identifier, TimeZone.autoupdatingCurrent.identifier)
    }

    func testFormatterKeepsGregorianYearForNonGregorianLocale() {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let formatter = EquinoxFormatters.makeFormatter(
            locale: Locale(identifier: "ja_JP@calendar=japanese"),
            timeZone: timeZone
        ) {
            $0.dateFormat = "yyyy"
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 30))!

        XCTAssertEqual(formatter.calendar.identifier, .gregorian)
        XCTAssertEqual(formatter.string(from: date), "2026")
    }
}
