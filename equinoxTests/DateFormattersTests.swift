import XCTest
@testable import EquinoxKit

final class DateFormattersTests: XCTestCase {
    func testConcurrentFormattingAndCacheInvalidationKeepStableResults() async {
        let date = Date(timeIntervalSince1970: 1_791_000_000)
        let expected = EquinoxFormatters.shortTime(date)
        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for worker in 0..<8 {
                group.addTask {
                    for iteration in 0..<100 {
                        if (worker + iteration) % 7 == 0 { EquinoxFormatters.invalidateCache() }
                        guard EquinoxFormatters.shortTime(date) == expected else { return false }
                    }
                    return true
                }
            }
            var results: [Bool] = []
            for await result in group { results.append(result) }
            return results
        }
        XCTAssertEqual(results.count, 8)
        XCTAssertTrue(results.allSatisfy { $0 })
    }

    func testSameDayEventShowsItsDateOnlyOnce() {
        let calendar = Calendar.equinoxGregorian()
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 11))!
        let end = start.addingTimeInterval(3600)
        let date = EquinoxFormatters.formatter(key: "test.date-only") { $0.dateStyle = .medium }.string(from: start)
        let text = EquinoxFormatters.mediumDateTime(from: start, to: end)
        XCTAssertEqual(text.components(separatedBy: date).count - 1, 1)
        XCTAssertTrue(text.contains(EquinoxFormatters.shortTime(start)))
        XCTAssertTrue(text.hasSuffix(EquinoxFormatters.shortTime(end)))
    }

    func testOvernightEventKeepsBothDates() {
        let calendar = Calendar.equinoxGregorian()
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 23))!
        let end = start.addingTimeInterval(7200)
        let date = EquinoxFormatters.formatter(key: "test.date-only") { $0.dateStyle = .medium }
        let text = EquinoxFormatters.mediumDateTime(from: start, to: end)
        XCTAssertTrue(text.contains(date.string(from: start)))
        XCTAssertTrue(text.contains(date.string(from: end)))
    }

    func testExplicitInvalidationReleasesCachedFormatterAndReconfiguresIt() {
        EquinoxFormatters.invalidateCache()
        defer { EquinoxFormatters.invalidateCache() }
        weak var first: DateFormatter?
        autoreleasepool {
            let formatter = EquinoxFormatters.formatter(key: "test.locale-overrides") { $0.dateFormat = "HH" }
            first = formatter
            EquinoxFormatters.invalidateCache()
        }
        XCTAssertNil(first, "Invalidation must release cached formatters before the next lookup")
        let second = EquinoxFormatters.formatter(key: "test.locale-overrides") { $0.dateFormat = "hh" }
        XCTAssertEqual(second.dateFormat, "hh")
    }

    func testCacheRefreshesWhenEitherLocaleOrTimeZoneChangesAndReusesUnchangedContext() {
        EquinoxFormatters.invalidateCache()
        defer { EquinoxFormatters.invalidateCache() }
        let english = Locale(identifier: "en_US_POSIX")
        let russian = Locale(identifier: "ru_RU")
        let utc = TimeZone(secondsFromGMT: 0)!
        let plusThree = TimeZone(secondsFromGMT: 3 * 3600)!
        let contexts = [
            (english, utc, "00:00"),
            (russian, utc, "00:00"),
            (russian, plusThree, "03:00"),
            (russian, utc, "00:00"),
            (english, utc, "00:00"),
        ]
        var previous: DateFormatter?
        for (locale, timeZone, expectedTime) in contexts {
            let formatter = EquinoxFormatters.formatter(key: "test.context", locale: locale, timeZone: timeZone) {
                $0.dateFormat = "HH:mm"
            }
            XCTAssertFalse(formatter === previous, "A changed context must rebuild the cached formatter")
            XCTAssertEqual(formatter.locale.identifier, locale.identifier)
            XCTAssertEqual(formatter.timeZone.identifier, timeZone.identifier)
            XCTAssertEqual(formatter.string(from: Date(timeIntervalSince1970: 0)), expectedTime)
            let reused = EquinoxFormatters.formatter(key: "test.context", locale: locale, timeZone: timeZone) { _ in
                XCTFail("An unchanged context must reuse the formatter without reconfiguring it")
            }
            XCTAssertTrue(formatter === reused)
            previous = formatter
        }
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
