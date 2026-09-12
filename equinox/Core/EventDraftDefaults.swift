import Foundation

enum EventDraftDefaults {
    /// Picker bounds; the following midnight remains a valid exclusive event end.
    static func supportedDateRange(calendar: Calendar) -> ClosedRange<Date> {
        CalendarDate.minimumSupported.date(in: calendar)...CalendarDate.maximumSupported
            .addingDays(1).date(in: calendar).addingTimeInterval(-1)
    }

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
            guard let host = url.host(), !host.isEmpty else { return nil }
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
        if let initial = initialDate, initial != CalendarDate(date: now, calendar: calendar) {
            var components = calendar.dateComponents([.year, .month, .day], from: initial.date(in: calendar))
            components.hour = calendar.component(.hour, from: roundedNow)
            components.minute = calendar.component(.minute, from: roundedNow)
            if let rounded = calendar.date(from: components) {
                roundedStart = rounded
            } else {
                roundedStart = initial.date(in: calendar)
            }
        } else {
            roundedStart = roundedNow
        }
        let supported = supportedDateRange(calendar: calendar)
        let start = min(max(roundedStart, supported.lowerBound), supported.upperBound)
        let end = calendar.date(byAdding: .minute, value: 60, to: start) ?? start
        return (start, min(end, supported.upperBound.addingTimeInterval(1)))
    }

    static func endDatePreservingDuration(
        previousStart: Date,
        previousEnd: Date,
        newStart: Date,
        calendar: Calendar,
        isAllDay: Bool = false
    ) -> Date {
        if isAllDay {
            // The draft's end day is inclusive; hidden clock values must not add a day.
            guard previousStart.timeIntervalSinceReferenceDate.isFinite,
                  previousEnd.timeIntervalSinceReferenceDate.isFinite,
                  newStart.timeIntervalSinceReferenceDate.isFinite else { return newStart }
            let daySpan = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: previousStart), to: calendar.startOfDay(for: previousEnd)
            ).day ?? 0
            return calendar.date(byAdding: .day, value: max(0, daySpan), to: calendar.startOfDay(for: newStart)) ?? newStart
        }

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
        // A minute interval preserves the actual occurrence of a repeated DST hour.
        guard let minuteStart = calendar.dateInterval(of: .minute, for: date)?.start else { return date }
        let minuteRemainder = calendar.component(.minute, from: date) % 30
        if minuteRemainder == 0, date == minuteStart {
            return minuteStart
        }
        return calendar.date(byAdding: .minute, value: 30 - minuteRemainder, to: minuteStart) ?? date
    }
}
