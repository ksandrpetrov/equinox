import Foundation

enum AgendaFocus {
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
