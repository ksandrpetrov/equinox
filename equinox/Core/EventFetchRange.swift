import Foundation

enum EventFetchRange {
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
}
