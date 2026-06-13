import XCTest
@testable import equinox

final class CalendarDateTests: XCTestCase {
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

    func testWeekOfYear() {
        XCTAssertEqual(CalendarDate.weekOfYear(year: 2024, monthIndex: 0, day: 1), 1)
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
