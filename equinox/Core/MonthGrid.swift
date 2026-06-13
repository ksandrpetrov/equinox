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
