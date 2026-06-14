import Foundation

enum AgendaSections {
    static func sections(
        from startDate: CalendarDate,
        days: Int,
        showEmptyDays: Bool,
        eventsFor: (CalendarDate) -> [DayEvent]
    ) -> [(date: CalendarDate, events: [DayEvent])] {
        guard days > 0 else { return [] }
        return sections(
            from: startDate,
            through: startDate.addingDays(days - 1),
            pinnedDate: nil,
            showEmptyDays: showEmptyDays,
            eventsFor: eventsFor
        )
    }

    static func sections(
        from firstDate: CalendarDate,
        through lastDate: CalendarDate,
        pinnedDate: CalendarDate?,
        showEmptyDays: Bool,
        eventsFor: (CalendarDate) -> [DayEvent]
    ) -> [(date: CalendarDate, events: [DayEvent])] {
        guard firstDate <= lastDate else { return [] }
        var result: [(CalendarDate, [DayEvent])] = []
        var date = firstDate
        while date <= lastDate {
            let events = eventsFor(date)
            if !events.isEmpty || showEmptyDays || date == pinnedDate {
                result.append((date, events))
            }
            date = date.addingDays(1)
        }
        return result
    }
}
