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
        // is device-independent and aligns with calendar instants. Some values also carry
        // sub-second precision without a timezone (e.g. "2026-06-11T11:04:11.544000"), which
        // neither ISO8601DateFormatter (requires a zone) nor the plain formats below accept,
        // so drop the fractional part before parsing. Epoch strings (with ".") are already
        // handled by parseEpoch above, so the only remaining "." here is a fractional second.
        let naive = text.firstIndex(of: ".").map { String(text[..<$0]) } ?? text
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
            if let date = formatter.date(from: naive) { return date }
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

    /// Prefers the recording start instant (`start_at`) over file creation / summarization
    /// time (`created_at`). The Plaud developer `files/` endpoint creates the file when the
    /// summary is generated — often the next day — so keying matches on `created_at` shifts
    /// recordings onto the wrong day. `start_at` is the actual recording (meeting) start.
    static func parseRecordingStartedAt(from raw: [String: Any]) -> Date? {
        let startKeys = ["start_at", "startAt"]
        for key in startKeys {
            if let value = raw[key], let date = parseCreatedAt(value) {
                return date
            }
        }

        let fallbackKeys = ["created_at", "createdAt"]
        for key in fallbackKeys {
            if let value = raw[key], let date = parseCreatedAt(value) {
                return date
            }
        }
        return nil
    }

    /// Parses a duration value from the Plaud developer API (milliseconds).
    static func durationSeconds(from value: Any?) -> TimeInterval? {
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
        guard let milliseconds = raw, milliseconds >= 0 else { return nil }
        return milliseconds / 1000
    }
}
