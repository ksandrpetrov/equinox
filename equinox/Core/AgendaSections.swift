import Foundation

enum AgendaSections {
    static func sections(
        from startDate: CalendarDate,
        days: Int,
        showEmptyDays: Bool,
        eventsFor: (CalendarDate) -> [DayEvent]
    ) -> [(date: CalendarDate, events: [DayEvent])] {
        var result: [(CalendarDate, [DayEvent])] = []
        var date = startDate
        let end = date.addingDays(days)
        while date < end {
            let events = eventsFor(date)
            if !events.isEmpty || showEmptyDays {
                result.append((date, events))
            }
            date = date.addingDays(1)
        }
        return result
    }
}
