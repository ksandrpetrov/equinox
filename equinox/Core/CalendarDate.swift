import Foundation

struct CalendarDate: Equatable, Hashable, Sendable {
    var year: Int
    var monthIndex: Int
    var day: Int
    var julian: Int

    static let noJulian = -1
    static let minYear = 1583
    static let maxYear = 3333

    init(year: Int, monthIndex: Int, day: Int) {
        self.year = year
        self.monthIndex = monthIndex
        self.day = day
        self.julian = Self.makeJulian(year: year, monthIndex: monthIndex, day: day)
    }

    init(julian: Int) {
        let gregorian = Self.makeGregorian(julian: julian)
        self = gregorian
    }

    init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(
            year: components.year ?? Self.minYear,
            monthIndex: (components.month ?? 1) - 1,
            day: components.day ?? 1
        )
    }

    static func today(calendar: Calendar) -> CalendarDate {
        CalendarDate(date: Date(), calendar: calendar)
    }

    func date(in calendar: Calendar) -> Date {
        var components = DateComponents()
        components.era = 1
        components.year = year
        components.month = monthIndex + 1
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        let nsDate = calendar.date(from: components)!
        return calendar.startOfDay(for: nsDate)
    }

    func addingDays(_ days: Int) -> CalendarDate {
        var copy = self
        if copy.julian == Self.noJulian {
            copy.julian = Self.makeJulian(year: year, monthIndex: monthIndex, day: day)
        }
        return CalendarDate(julian: copy.julian + days)
    }

    func addingMonths(_ months: Int) -> CalendarDate {
        var newYear = year + months / 12
        var newMonth = monthIndex + months % 12
        if newMonth > 11 {
            newMonth -= 12
            newYear += 1
        } else if newMonth < 0 {
            newMonth += 12
            newYear -= 1
        }
        return CalendarDate(year: newYear, monthIndex: newMonth, day: 1)
    }

    /// Shifts by calendar months while keeping the day-of-month, clamping to the target month's length.
    func addingMonthsPreservingDay(_ months: Int, calendar: Calendar) -> CalendarDate {
        var components = DateComponents()
        components.year = year
        components.month = monthIndex + 1
        components.day = day
        guard let baseDate = calendar.date(from: components),
              let shifted = calendar.date(byAdding: .month, value: months, to: baseDate) else {
            return addingMonths(months)
        }
        return CalendarDate(date: shifted, calendar: calendar)
    }

    func compare(_ other: CalendarDate) -> Int {
        let j1 = julian == Self.noJulian ? Self.makeJulian(year: year, monthIndex: monthIndex, day: day) : julian
        let j2 = other.julian == Self.noJulian
            ? Self.makeJulian(year: other.year, monthIndex: other.monthIndex, day: other.day)
            : other.julian
        return j1 - j2
    }

    func isSameCalendarDay(as other: CalendarDate) -> Bool {
        compare(other) == 0
    }

    var isValid: Bool {
        year >= Self.minYear &&
            year <= Self.maxYear &&
            monthIndex >= 0 &&
            monthIndex <= 11 &&
            day >= 1 &&
            day <= Self.daysInMonth(year: year, monthIndex: monthIndex)
    }

    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4) == 0 && ((year % 100) != 0 || (year % 400) == 0)
    }

    static func daysInMonth(year: Int, monthIndex: Int) -> Int {
        (monthIndex == 1 && isLeapYear(year)) ? 29 : kDaysInMonth[monthIndex]
    }

    static func weeksInYear(_ year: Int) -> Int {
        let jan1DOW = (2 + year + 4 + year / 4 - year / 100 + year / 400) % 7
        if jan1DOW == 4 || (jan1DOW == 3 && isLeapYear(year)) {
            return 53
        }
        return 52
    }

    static func weekOfYear(year: Int, monthIndex: Int, day: Int) -> Int {
        var dayOfYear = kMonthDaysSoFar[monthIndex] + day
        if monthIndex > 1 && isLeapYear(year) {
            dayOfYear += 1
        }
        let week = (dayOfYear + 9) / 7
        if week > weeksInYear(year) {
            return 1
        }
        if week < 1 {
            return weeksInYear(year - 1)
        }
        return week
    }

    static func makeJulian(year: Int, monthIndex: Int, day: Int) -> Int {
        var m = monthIndex + 1
        var y = year
        if m > 2 {
            m -= 3
        } else {
            m += 9
            y -= 1
        }
        let c = y / 100
        let ya = y - 100 * c
        return 146097 * c / 4 + 1461 * ya / 4 + (153 * m + 2) / 5 + day + 1721119
    }

    static func makeGregorian(julian: Int) -> CalendarDate {
        var j = julian
        j -= 1721119
        var y = (4 * j - 1) / 146097
        j = 4 * j - 1 - 146097 * y
        var d = j / 4
        j = (4 * d + 3) / 1461
        d = 4 * d + 3 - 1461 * j
        d = (d + 4) / 4
        var m = (5 * d - 3) / 153
        d = 5 * d - 3 - 153 * m
        d = (d + 5) / 5
        y = 100 * y + j
        if m < 10 {
            m += 3
        } else {
            m -= 9
            y += 1
        }
        m -= 1
        return CalendarDate(year: y, monthIndex: m, day: d, julian: julian)
    }

    private init(year: Int, monthIndex: Int, day: Int, julian: Int) {
        self.year = year
        self.monthIndex = monthIndex
        self.day = day
        self.julian = julian
    }
}

private let kDaysInMonth: [Int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
private let kMonthDaysSoFar: [Int] = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]

extension CalendarDate: Comparable {
    static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        lhs.compare(rhs) < 0
    }
}
