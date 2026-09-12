import XCTest
@testable import EquinoxKit

final class MonthGridTests: XCTestCase {
    func testGridIsContinuousAndCoversEveryMonthAcrossSupportedLayouts() {
        for year in [CalendarDate.minYear, 1900, 2000, 2024, CalendarDate.maxYear] {
            for month in 0..<12 {
                for weekStart in 0..<7 {
                    for rows in 6...10 {
                        let first = CalendarDate(year: year, monthIndex: month, day: 1)
                        let dates = monthGridDates(monthDate: first, weekStartWeekday: weekStart, numRows: rows)
                        XCTAssertEqual(dates.count, rows * 7)
                        XCTAssertEqual((dates[0].julian + 1) % 7, weekStart)
                        XCTAssertTrue(dates.contains(first))
                        XCTAssertTrue(dates.contains(CalendarDate(year: year, monthIndex: month, day: CalendarDate.daysInMonth(year: year, monthIndex: month))))
                        for (index, date) in dates.enumerated() {
                            XCTAssertEqual(date.julian, dates[0].julian + index)
                            XCTAssertEqual(weekdayForColumn(startDOW: weekStart, col: index % 7), (date.julian + 1) % 7)
                        }
                    }
                }
            }
        }
    }

    func testBoundaryFlagsMarkOnlyVisibleMonthRowEndpoints() {
        for month in 0..<12 {
            for weekStart in 0..<7 {
                let dates = monthGridDates(monthDate: CalendarDate(year: 2026, monthIndex: month, day: 1), weekStartWeekday: weekStart, numRows: 6)
                for (index, date) in dates.enumerated() {
                    let flags = monthGridBoundaryFlags(for: date, monthIndex: month, col: index % 7, row: index / 7, gridDates: dates, showMonthBoundaries: true)
                    XCTAssertEqual(flags.start, date.monthIndex == month && (date.day == 1 || index % 7 == 0))
                    XCTAssertEqual(flags.end, date.monthIndex == month && (date.day == CalendarDate.daysInMonth(year: 2026, monthIndex: month) || index % 7 == 6))
                    let hidden = monthGridBoundaryFlags(for: date, monthIndex: month, col: index % 7, row: index / 7, gridDates: dates, showMonthBoundaries: false)
                    XCTAssertFalse(hidden.start || hidden.end)
                }
            }
        }
    }
}
