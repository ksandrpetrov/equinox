import Foundation

enum EventFetchRange {
    /// Pending fetches close to each other are merged. A larger span almost always means
    /// the user jumped to another date, so the latest range supersedes stale pending work.
    static let maximumCoalescedSpanDays = 370

    static func range(
        coveringGridFrom gridFirst: CalendarDate,
        through gridLast: CalendarDate,
        agendaFirst: CalendarDate?,
        agendaLast: CalendarDate?
    ) -> (first: CalendarDate, last: CalendarDate) {
        var fetchFirst = gridFirst
        var fetchLast = gridLast
        if let agendaFirst, agendaFirst < fetchFirst {
            fetchFirst = agendaFirst
        }
        if let agendaLast, agendaLast > fetchLast {
            fetchLast = agendaLast
        }
        return (fetchFirst, fetchLast)
    }

    static func coalesced(
        current: (first: CalendarDate, last: CalendarDate),
        incoming: (first: CalendarDate, last: CalendarDate)
    ) -> (first: CalendarDate, last: CalendarDate) {
        let merged = (
            first: min(current.first, incoming.first),
            last: max(current.last, incoming.last)
        )
        guard merged.last.compare(merged.first) <= maximumCoalescedSpanDays else {
            return incoming
        }
        return merged
    }
}
