import Foundation

/// Builds the calendar grid dates for a month view.
func monthGridDates(
    monthDate: CalendarDate,
    weekStartWeekday: Int,
    numRows: Int
) -> [CalendarDate] {
    let firstOfMonth = CalendarDate(year: monthDate.year, monthIndex: monthDate.monthIndex, day: 1)
    let monthStartDOW = (firstOfMonth.julian + 1) % 7
    let monthStartColumn = columnForWeekday(startDOW: weekStartWeekday, dow: monthStartDOW)
    var date = firstOfMonth.addingDays(-monthStartColumn)
    var dates: [CalendarDate] = []
    dates.reserveCapacity(numRows * 7)
    for _ in 0..<(numRows * 7) {
        dates.append(date)
        date = date.addingDays(1)
    }
    return dates
}

func columnForWeekday(startDOW: Int, dow: Int) -> Int {
    (7 - startDOW + dow) % 7
}

func weekdayForColumn(startDOW: Int, col: Int) -> Int {
    (startDOW + col) % 7
}

/// Returns start/end boundary flags for in-month cells when month boundaries are shown.
func monthGridBoundaryFlags(
    for date: CalendarDate,
    monthIndex: Int,
    col: Int,
    row: Int,
    gridDates: [CalendarDate],
    showMonthBoundaries: Bool
) -> (start: Bool, end: Bool) {
    guard showMonthBoundaries else { return (false, false) }
    let inMonth = date.monthIndex == monthIndex
    guard inMonth else { return (false, false) }

    let index = row * 7 + col
    let prevInMonth: Bool = {
        if col == 0 { return false }
        return gridDates[index - 1].monthIndex == monthIndex
    }()
    let nextInMonth: Bool = {
        if col == 6 { return false }
        return gridDates[index + 1].monthIndex == monthIndex
    }()

    let start = col == 0 || !prevInMonth
    let end = col == 6 || !nextInMonth
    return (start, end)
}
