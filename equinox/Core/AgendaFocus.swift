import Foundation

enum AgendaFocus {
    /// Delay before clearing programmatic-scroll guard after `scrollPosition` updates.
    static let programmaticScrollSettleDelay: TimeInterval = 0.35

    /// Timed event to scroll to, walking day-by-day from `firstDate`: the first day with an
    /// ongoing or upcoming timed event wins. nil → nothing ongoing/upcoming in the range.
    static func focusEventID(
        from firstDate: CalendarDate,
        through lastDate: CalendarDate,
        eventsFor: (CalendarDate) -> [DayEvent],
        now: Date = Date()
    ) -> String? {
        var date = firstDate
        while date <= lastDate {
            if let eventID = focusEventID(in: eventsFor(date), now: now) {
                return eventID
            }
            date = date.addingDays(1)
        }
        return nil
    }

    /// Timed event to scroll to: ongoing first, else next upcoming; nil → scroll to day header.
    static func focusEventID(in events: [DayEvent], now: Date = Date()) -> String? {
        let timed = events
            .filter { !$0.isEventAllDay }
            .sorted { $0.startDate < $1.startDate }

        if let ongoing = timed.first(where: { $0.startDate <= now && $0.endDate > now }) {
            return ongoing.id
        }
        if let next = timed.first(where: { $0.startDate > now }) {
            return next.id
        }
        return nil
    }
}
