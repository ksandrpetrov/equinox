import Foundation

enum MeetingIndicator {
    /// Returns whether any timed event with a join URL overlaps the next `lookaheadMinutes`.
    static func shouldShow(
        eventsByDate: [CalendarDate: [DayEvent]],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        lookaheadMinutes: Int = 30
    ) -> Bool {
        for (_, events) in eventsByDate {
            for event in events where isJoinActionUrgent(
                event,
                now: now,
                calendar: calendar,
                lookaheadMinutes: lookaheadMinutes
            ) {
                return true
            }
        }
        return false
    }

    static func isJoinActionUrgent(
        _ event: DayEvent,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        lookaheadMinutes: Int = 30
    ) -> Bool {
        guard event.joinURL != nil,
              AgendaFocus.temporalState(for: event, now: now) != .notApplicable else {
            return false
        }
        let end = calendar.date(byAdding: .minute, value: lookaheadMinutes, to: now) ?? now
        return event.startDate <= end && event.endDate > now
    }
}
