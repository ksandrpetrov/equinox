import Foundation

enum EventDraftDefaults {
    static func normalizedDates(
        calendar: Calendar,
        start: Date,
        end: Date,
        isAllDay: Bool
    ) -> (start: Date, end: Date)? {
        guard isAllDay else {
            return end > start ? (start, end) : nil
        }

        let startDay = calendar.startOfDay(for: start)
        let inclusiveEndDay = calendar.startOfDay(for: end)
        guard inclusiveEndDay >= startDay,
              let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: inclusiveEndDay) else {
            return nil
        }
        return (startDay, exclusiveEnd)
    }

    static func absoluteURL(from value: String) -> URL? {
        guard let url = URL(string: value), let scheme = url.scheme, !scheme.isEmpty else { return nil }
        if scheme.lowercased() == "http" || scheme.lowercased() == "https" {
            guard url.host() != nil else { return nil }
        }
        return url
    }

    static func normalizedRecurrenceEnd(
        calendar: Calendar,
        eventStart: Date,
        selectedEnd: Date
    ) -> Date? {
        let eventStartDay = calendar.startOfDay(for: eventStart)
        let selectedEndDay = calendar.startOfDay(for: selectedEnd)
        guard selectedEndDay >= eventStartDay,
              let followingDay = calendar.date(byAdding: .day, value: 1, to: selectedEndDay) else {
            return nil
        }
        return followingDay.addingTimeInterval(-1)
    }

    static func defaultStartAndEnd(
        calendar: Calendar,
        initialDate: CalendarDate?
    ) -> (start: Date, end: Date) {
        let roundedStart: Date
        if let initial = initialDate {
            var components = calendar.dateComponents([.year, .month, .day], from: initial.date(in: calendar))
            let now = Date()
            let nowHour = calendar.component(.hour, from: now)
            let nowMinute = calendar.component(.minute, from: now)
            components.hour = nowMinute >= 30 ? nowHour + 1 : nowHour
            components.minute = 0
            if let rounded = calendar.date(from: components) {
                roundedStart = rounded
            } else {
                roundedStart = initial.date(in: calendar)
            }
        } else {
            let now = Date()
            let minute = calendar.component(.minute, from: now)
            let hour = calendar.component(.hour, from: now)
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = minute >= 30 ? hour + 1 : hour
            components.minute = 0
            roundedStart = calendar.date(from: components) ?? now
        }
        let end = calendar.date(byAdding: .minute, value: 60, to: roundedStart) ?? roundedStart
        return (roundedStart, end)
    }

    static func recurrenceDraft(fromIndex index: Int, endDateIndex: Int, endDate: Date) -> RecurrenceDraft? {
        guard index > 0 else { return nil }
        let frequency: RecurrenceFrequency
        switch index {
        case 1: frequency = .daily
        case 2: frequency = .weekly
        case 3: frequency = .biweekly
        case 4: frequency = .monthly
        default: frequency = .yearly
        }
        let resolvedEndDate = endDateIndex == 1 ? endDate : nil
        return RecurrenceDraft(frequency: frequency, endDate: resolvedEndDate)
    }

    static func alertOffset(forPickerIndex index: Int) -> TimeInterval? {
        let offsets: [TimeInterval] = [.infinity, 0, -300, -600, -900, -1800, -3600, -7200, -86400, -172800]
        guard index > 0, index < offsets.count, offsets[index] != .infinity else { return nil }
        return offsets[index]
    }

    static func preferredCalendarIdentifier(
        currentIdentifier: String,
        defaultIdentifier: String?,
        availableIdentifiers: [String]
    ) -> String {
        if availableIdentifiers.contains(currentIdentifier) {
            return currentIdentifier
        }
        if let defaultIdentifier, availableIdentifiers.contains(defaultIdentifier) {
            return defaultIdentifier
        }
        return availableIdentifiers.first ?? ""
    }
}
