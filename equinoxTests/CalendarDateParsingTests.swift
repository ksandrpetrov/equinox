import XCTest
@testable import EquinoxKit

final class CalendarDateParsingTests: XCTestCase {
    func testParseValidDayString() {
        XCTAssertEqual(
            CalendarDateParsing.parseDayString("2026-06-14"),
            CalendarDate(year: 2026, monthIndex: 5, day: 14)
        )
    }

    func testParseLeapDay() {
        XCTAssertEqual(
            CalendarDateParsing.parseDayString("2024-02-29"),
            CalendarDate(year: 2024, monthIndex: 1, day: 29)
        )
    }

    func testRejectsInvalidCalendarDate() {
        XCTAssertNil(CalendarDateParsing.parseDayString("2026-13-01"))
        XCTAssertNil(CalendarDateParsing.parseDayString("2026-00-15"))
        XCTAssertNil(CalendarDateParsing.parseDayString("2026-06-32"))
        XCTAssertNil(CalendarDateParsing.parseDayString("2026-02-29"))
        XCTAssertNil(CalendarDateParsing.parseDayString("2026-02-30"))
        XCTAssertNil(CalendarDateParsing.parseDayString("1582-12-31"))
        XCTAssertNil(CalendarDateParsing.parseDayString("3334-01-01"))
    }

    func testRejectsMalformedStrings() {
        XCTAssertNil(CalendarDateParsing.parseDayString("2026-1-014"))
        XCTAssertNil(CalendarDateParsing.parseDayString("2026-1-001"))
        XCTAssertNil(CalendarDateParsing.parseDayString("2026-+1-01"))
        XCTAssertNil(CalendarDateParsing.parseDayString("+2026-1-01"))
        XCTAssertNil(CalendarDateParsing.parseDayString("2026-6-14"))
        XCTAssertNil(CalendarDateParsing.parseDayString("2026/06/14"))
        XCTAssertNil(CalendarDateParsing.parseDayString(""))
        XCTAssertNil(CalendarDateParsing.parseDayString("not-a-date"))
    }
}
