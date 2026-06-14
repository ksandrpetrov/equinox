import Foundation

enum AgendaDisplayRange {
    /// Visible agenda window centered on `anchor`, spanning `showEventDays` calendar days.
    static func range(anchor: CalendarDate, showEventDays: Int) -> (first: CalendarDate, last: CalendarDate) {
        guard showEventDays > 0 else { return (anchor, anchor) }
        let daysBefore = (showEventDays - 1) / 2
        let daysAfter = showEventDays - 1 - daysBefore
        return (
            first: anchor.addingDays(-daysBefore),
            last: anchor.addingDays(daysAfter)
        )
    }
}
