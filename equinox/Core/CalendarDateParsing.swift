import Foundation

enum CalendarDateParsing {
    /// Parses `yyyy-MM-dd` deep-link date paths into `CalendarDate`.
    static func parseDayString(_ value: String) -> CalendarDate? {
        guard value.count == 10 else { return nil }
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              (1...31).contains(day) else {
            return nil
        }
        let candidate = CalendarDate(year: year, monthIndex: month - 1, day: day)
        guard candidate.year == year,
              candidate.monthIndex == month - 1,
              candidate.day == day else {
            return nil
        }
        return candidate
    }
}
