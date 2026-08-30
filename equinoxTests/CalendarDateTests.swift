import XCTest
@testable import equinox

final class CalendarDateTests: XCTestCase {
    func testEquinoxCalendarKeepsGregorianDateContractForNonGregorianLocale() {
        let calendar = Calendar.equinoxGregorian(
            locale: Locale(identifier: "ja_JP@calendar=japanese"),
            timeZone: TimeZone(identifier: "Asia/Tokyo")!
        )
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let instant = utc.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 12))!

        let calendarDate = CalendarDate(date: instant, calendar: calendar)

        XCTAssertEqual(calendar.identifier, .gregorian)
        XCTAssertEqual(calendarDate, CalendarDate(year: 2026, monthIndex: 7, day: 30))
        XCTAssertTrue(calendarDate.isValid)
    }

    func testEquinoxCalendarTracksAutoupdatingLocaleAndTimeZone() {
        let calendar = Calendar.equinoxGregorian()

        XCTAssertEqual(calendar.identifier, .gregorian)
        XCTAssertEqual(calendar.locale?.identifier, Locale.autoupdatingCurrent.identifier)
        XCTAssertEqual(calendar.timeZone.identifier, TimeZone.autoupdatingCurrent.identifier)
    }

    func testSupportedBoundaryDatesRoundTripThroughEquinoxCalendar() {
        let calendar = Calendar.equinoxGregorian(
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        for boundary in [CalendarDate.minimumSupported, CalendarDate.maximumSupported] {
            XCTAssertEqual(
                CalendarDate(date: boundary.date(in: calendar), calendar: calendar),
                boundary
            )
        }
    }

    func testJulianRoundTrip() {
        let date = CalendarDate(year: 2024, monthIndex: 5, day: 15)
        let roundTripped = CalendarDate(julian: date.julian)
        XCTAssertEqual(date, roundTripped)
    }

    func testLeapYearFebruary() {
        XCTAssertEqual(CalendarDate.daysInMonth(year: 2024, monthIndex: 1), 29)
        XCTAssertEqual(CalendarDate.daysInMonth(year: 2023, monthIndex: 1), 28)
    }

    func testAddDaysCrossMonth() {
        let date = CalendarDate(year: 2024, monthIndex: 0, day: 31)
        let next = date.addingDays(1)
        XCTAssertEqual(next.year, 2024)
        XCTAssertEqual(next.monthIndex, 1)
        XCTAssertEqual(next.day, 1)
    }

    func testAddMonths() {
        let date = CalendarDate(year: 2024, monthIndex: 10, day: 1)
        let next = date.addingMonths(2)
        XCTAssertEqual(next.year, 2025)
        XCTAssertEqual(next.monthIndex, 0)
        XCTAssertEqual(next.day, 1)
    }

    func testAddMonthsPreservingDay() {
        let jan31 = CalendarDate(year: 2024, monthIndex: 0, day: 31)
        let feb = jan31.addingMonthsPreservingDay(1, calendar: Calendar(identifier: .gregorian))
        XCTAssertEqual(feb.year, 2024)
        XCTAssertEqual(feb.monthIndex, 1)
        XCTAssertEqual(feb.day, 29)

        let jun14 = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let may14 = jun14.addingMonthsPreservingDay(-1, calendar: Calendar(identifier: .gregorian))
        XCTAssertEqual(may14.year, 2026)
        XCTAssertEqual(may14.monthIndex, 4)
        XCTAssertEqual(may14.day, 14)
    }

    func testWeekOfYear() {
        XCTAssertEqual(CalendarDate.weekOfYear(year: 2024, monthIndex: 0, day: 1), 1)
        XCTAssertEqual(CalendarDate.weekOfYear(year: 2021, monthIndex: 0, day: 1), 53)
        XCTAssertEqual(CalendarDate.weekOfYear(year: 2020, monthIndex: 11, day: 31), 53)
        XCTAssertEqual(CalendarDate.weekOfYear(year: 2021, monthIndex: 0, day: 4), 1)
        XCTAssertEqual(CalendarDate.weekOfYear(year: 2024, monthIndex: 11, day: 31), 1)
        XCTAssertEqual(CalendarDate.weeksInYear(2020), 53)
        XCTAssertEqual(CalendarDate.weeksInYear(2021), 52)
    }

    func testCompareDates() {
        let earlier = CalendarDate(year: 2024, monthIndex: 0, day: 1)
        let later = CalendarDate(year: 2024, monthIndex: 0, day: 2)
        XCTAssertLessThan(earlier.compare(later), 0)
        XCTAssertGreaterThan(later.compare(earlier), 0)
        XCTAssertEqual(earlier.compare(earlier), 0)
    }

    func testYearBoundsAreValid() {
        XCTAssertTrue(CalendarDate(year: CalendarDate.minYear, monthIndex: 0, day: 1).isValid)
        XCTAssertTrue(CalendarDate(year: CalendarDate.maxYear, monthIndex: 11, day: 31).isValid)
        XCTAssertFalse(CalendarDate(year: CalendarDate.minYear - 1, monthIndex: 0, day: 1).isValid)
        XCTAssertFalse(CalendarDate(year: CalendarDate.maxYear + 1, monthIndex: 0, day: 1).isValid)
    }

    func testSameDayNumberDifferentMonthsAreNotEqual() {
        let february15 = CalendarDate(year: 2026, monthIndex: 1, day: 15)
        let march15 = CalendarDate(year: 2026, monthIndex: 2, day: 15)
        XCTAssertFalse(february15.isSameCalendarDay(as: march15))
    }
}
