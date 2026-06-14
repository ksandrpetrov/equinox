import Foundation

enum EventFetchRange {
    static func range(
        coveringGridFrom gridFirst: CalendarDate,
        through gridLast: CalendarDate,
        selectedDate: CalendarDate,
        agendaDays: Int
    ) -> (first: CalendarDate, last: CalendarDate) {
        var fetchFirst = gridFirst
        var fetchLast = gridLast
        guard agendaDays > 0 else { return (fetchFirst, fetchLast) }
        if selectedDate < fetchFirst {
            fetchFirst = selectedDate
        }
        let agendaLast = selectedDate.addingDays(agendaDays - 1)
        if agendaLast > fetchLast {
            fetchLast = agendaLast
        }
        return (fetchFirst, fetchLast)
    }
}
