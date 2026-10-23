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
                        guard dates.count == rows * 7 else { return }
                        let last = CalendarDate(year: year, monthIndex: month, day: CalendarDate.daysInMonth(year: year, monthIndex: month))
                        guard (dates[0].julian + 1) % 7 == weekStart, dates.contains(first), dates.contains(last) else {
                            XCTFail("Grid misses month endpoints or week start: \(year)-\(month + 1), week start \(weekStart), rows \(rows)")
                            return
                        }
                        for (index, date) in dates.enumerated() {
                            guard date.julian == dates[0].julian + index,
                                  weekdayForColumn(startDOW: weekStart, col: index % 7) == (date.julian + 1) % 7 else {
                                XCTFail("Discontinuous grid or wrong weekday: \(year)-\(month + 1), week start \(weekStart), rows \(rows), cell \(index): \(date)")
                                return
                            }
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
                XCTAssertEqual(dates.count, 42)
                guard dates.count == 42 else { return }
                for (index, date) in dates.enumerated() {
                    let flags = monthGridBoundaryFlags(for: date, monthIndex: month, col: index % 7, row: index / 7, gridDates: dates, showMonthBoundaries: true)
                    let expectedStart = date.monthIndex == month && (date.day == 1 || index % 7 == 0)
                    let expectedEnd = date.monthIndex == month && (date.day == CalendarDate.daysInMonth(year: 2026, monthIndex: month) || index % 7 == 6)
                    let hidden = monthGridBoundaryFlags(for: date, monthIndex: month, col: index % 7, row: index / 7, gridDates: dates, showMonthBoundaries: false)
                    guard flags.start == expectedStart, flags.end == expectedEnd, !hidden.start, !hidden.end else {
                        XCTFail("Wrong boundary flags: month \(month + 1), week start \(weekStart), cell \(index); shown \(flags), hidden \(hidden), expected (\(expectedStart), \(expectedEnd))")
                        return
                    }
                }
            }
        }
    }
}
