import XCTest
@testable import equinox

final class MonthGridTests: XCTestCase {
    func testDefaultGridHasExpectedCellCount() {
        let month = CalendarDate(year: 2024, monthIndex: 5, day: 1)
        let dates = monthGridDates(monthDate: month, weekStartWeekday: 1, numRows: 6)
        XCTAssertEqual(dates.count, 42)
    }

    func testGridStartsOnConfiguredWeekStart() {
        let month = CalendarDate(year: 2024, monthIndex: 5, day: 1)
        let dates = monthGridDates(monthDate: month, weekStartWeekday: 1, numRows: 6)
        guard let first = dates.first else {
            XCTFail("Expected grid dates")
            return
        }
        let firstDOW = (first.julian + 1) % 7
        XCTAssertEqual(columnForWeekday(startDOW: 1, dow: firstDOW), 0)
    }

    func testGridIncludesFirstOfMonth() {
        let month = CalendarDate(year: 2024, monthIndex: 5, day: 1)
        let dates = monthGridDates(monthDate: month, weekStartWeekday: 0, numRows: 6)
        XCTAssertTrue(dates.contains(where: { $0.year == 2024 && $0.monthIndex == 5 && $0.day == 1 }))
    }
}
