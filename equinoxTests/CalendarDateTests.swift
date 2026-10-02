import XCTest
@testable import EquinoxKit

final class CalendarDateTests: XCTestCase {
    func testMonthBoundariesAndISOWeeksAgreeWithFoundationAcrossSupportedYears() throws {
        let calendar = Calendar.equinoxGregorian(timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0)))
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        for year in CalendarDate.minYear...CalendarDate.maxYear {
            for month in 0..<12 {
                for day in [1, CalendarDate.daysInMonth(year: year, monthIndex: month)] {
                    let civil = CalendarDate(year: year, monthIndex: month, day: day)
                    let instant = try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month + 1, day: day)))
                    XCTAssertEqual(CalendarDate(date: instant, calendar: calendar), civil)
                    XCTAssertEqual(civil.date(in: calendar), instant)
                    XCTAssertEqual(CalendarDate.weekOfYear(year: year, monthIndex: month, day: day),
                                   iso.component(.weekOfYear, from: instant), "\(year)-\(month + 1)-\(day)")
                }
            }
        }
    }

    func testEverySupportedDayRoundTripsThroughJulianArithmetic() {
        for julian in CalendarDate.minimumSupported.julian...CalendarDate.maximumSupported.julian {
            let date = CalendarDate(julian: julian)
            guard date.isValid,
                  CalendarDate(year: date.year, monthIndex: date.monthIndex, day: date.day) == date else {
                XCTFail("Invalid Gregorian round trip at Julian day \(julian)")
                return
            }
        }
    }
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
        let feb = jan31.addingMonthsPreservingDay(1)
        XCTAssertEqual(feb.year, 2024)
        XCTAssertEqual(feb.monthIndex, 1)
        XCTAssertEqual(feb.day, 29)

        let jun14 = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let may14 = jun14.addingMonthsPreservingDay(-1)
        XCTAssertEqual(may14.year, 2026)
        XCTAssertEqual(may14.monthIndex, 4)
        XCTAssertEqual(may14.day, 14)
    }

    func testMonthNavigationPreservesCivilDatesAcrossSkippedLocalDay() {
        let november30 = CalendarDate(year: 2011, monthIndex: 10, day: 30)
        let december30 = CalendarDate(year: 2011, monthIndex: 11, day: 30)
        let january30 = CalendarDate(year: 2012, monthIndex: 0, day: 30)

        // The grid includes December 30 even though Apia skipped that local day.
        // Month navigation is civil-date arithmetic, not conversion to an instant.
        XCTAssertEqual(november30.addingMonthsPreservingDay(1), december30)
        XCTAssertEqual(january30.addingMonthsPreservingDay(-1), december30)
        XCTAssertEqual(december30.addingMonthsPreservingDay(1), january30)
        XCTAssertEqual(december30.addingMonthsPreservingDay(-1), november30)
        XCTAssertEqual(december30.addingMonthsPreservingDay(0), december30)
    }

    func testMonthShiftsClampLeapDaysAcrossCenturiesAndSupportedBoundaries() {
        let cases: [(CalendarDate, Int, CalendarDate)] = [
            (.init(year: 2000, monthIndex: 1, day: 29), 12, .init(year: 2001, monthIndex: 1, day: 28)),
            (.init(year: 2000, monthIndex: 1, day: 29), -1200, .init(year: 1900, monthIndex: 1, day: 28)),
            (.init(year: 2000, monthIndex: 1, day: 29), -4800, .init(year: 1600, monthIndex: 1, day: 29)),
            (.init(year: 2026, monthIndex: 0, day: 31), 3, .init(year: 2026, monthIndex: 3, day: 30)),
            (.minimumSupported, 1, .init(year: 1583, monthIndex: 1, day: 1)),
            (.maximumSupported, -1, .init(year: 3333, monthIndex: 10, day: 30)),
        ]
        for (source, months, expected) in cases {
            XCTAssertEqual(source.addingMonthsPreservingDay(months), expected)
        }
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
