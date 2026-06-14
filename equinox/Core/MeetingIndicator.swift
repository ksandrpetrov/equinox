import Foundation

enum MeetingIndicator {
    /// Returns whether any timed event with a join URL overlaps the next `lookaheadMinutes`.
    static func shouldShow(
        eventsByDate: [CalendarDate: [DayEvent]],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        lookaheadMinutes: Int = 30
    ) -> Bool {
        let end = calendar.date(byAdding: .minute, value: lookaheadMinutes, to: now) ?? now
        for (_, events) in eventsByDate {
            for event in events where !event.isEventAllDay {
                if event.startDate <= end && event.endDate > now, event.joinURL != nil {
                    return true
                }
            }
        }
        return false
    }
}
