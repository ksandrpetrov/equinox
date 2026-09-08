import Foundation

enum CalendarDateParsing {
    /// Parses `yyyy-MM-dd` deep-link date paths into `CalendarDate`.
    static func parseDayString(_ value: String) -> CalendarDate? {
        let bytes = Array(value.utf8)
        guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
              bytes.enumerated().allSatisfy({ index, byte in
                  index == 4 || index == 7 || (48...57).contains(byte)
              }) else { return nil }
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
        return candidate.isValid ? candidate : nil
    }
}
