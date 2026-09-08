import Foundation

enum EventDraftDefaults {
    static func normalizedDates(
        calendar: Calendar,
        start: Date,
        end: Date,
        isAllDay: Bool
    ) -> (start: Date, end: Date)? {
        guard start.timeIntervalSinceReferenceDate.isFinite,
              end.timeIntervalSinceReferenceDate.isFinite else { return nil }
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
        initialDate: CalendarDate?,
        now: Date = Date()
    ) -> (start: Date, end: Date) {
        let roundedNow = roundedUpToHalfHour(now, calendar: calendar)
        let roundedStart: Date
        if let initial = initialDate {
            var components = calendar.dateComponents([.year, .month, .day], from: initial.date(in: calendar))
            components.hour = calendar.component(.hour, from: roundedNow)
            components.minute = calendar.component(.minute, from: roundedNow)
            if let rounded = calendar.date(from: components) {
                let today = CalendarDate(date: now, calendar: calendar)
                if initial == today, rounded < now {
                    roundedStart = calendar.date(byAdding: .day, value: 1, to: rounded) ?? roundedNow
                } else {
                    roundedStart = rounded
                }
            } else {
                roundedStart = initial.date(in: calendar)
            }
        } else {
            roundedStart = roundedNow
        }
        let end = calendar.date(byAdding: .minute, value: 60, to: roundedStart) ?? roundedStart
        return (roundedStart, end)
    }

    static func endDatePreservingDuration(
        previousStart: Date,
        previousEnd: Date,
        newStart: Date,
        calendar: Calendar
    ) -> Date {
        let duration = previousEnd.timeIntervalSince(previousStart)
        if duration.isFinite, duration > 0 {
            let preservedEnd = newStart.addingTimeInterval(duration)
            if preservedEnd.timeIntervalSinceReferenceDate.isFinite, preservedEnd > newStart {
                return preservedEnd
            }
        }

        if let fallback = calendar.date(byAdding: .minute, value: 60, to: newStart), fallback > newStart {
            return fallback
        }
        return newStart.addingTimeInterval(60 * 60)
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

    private static func roundedUpToHalfHour(_ date: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents(
            [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: date
        )
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let nanosecond = components.nanosecond ?? 0
        let minuteRemainder = minute % 30

        components.minute = minute - minuteRemainder
        components.second = 0
        components.nanosecond = 0
        guard let lowerBoundary = calendar.date(from: components) else { return date }

        if minuteRemainder == 0, second == 0, nanosecond == 0 {
            return lowerBoundary
        }
        return calendar.date(byAdding: .minute, value: 30, to: lowerBoundary) ?? date
    }
}
