import Foundation

enum PlaudTimestamp {
    static func parseCreatedAt(_ value: Any?) -> Date? {
        if let date = parseEpoch(value) { return date }

        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }

        if let date = parseEpoch(text) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }

        // Plaud API timestamps may omit a timezone; treat naive values as UTC so parsing
        // is device-independent and aligns with calendar instants.
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// Parses a numeric epoch (seconds or milliseconds) delivered either as a JSON number
    /// or a purely numeric string.
    static func parseEpoch(_ value: Any?) -> Date? {
        let raw: Double?
        if let number = value as? NSNumber, !(value is String) {
            raw = number.doubleValue
        } else if let text = value as? String,
                  !text.isEmpty,
                  text.allSatisfy({ $0.isNumber || $0 == "." }),
                  let number = Double(text) {
            raw = number
        } else {
            raw = nil
        }
        // Reject small values (e.g. a bare "2026") that are not plausible epochs.
        guard let value = raw, value >= 100_000_000 else { return nil }
        let seconds = value > 1_000_000_000_000 ? value / 1000 : value
        return Date(timeIntervalSince1970: seconds)
    }
}
