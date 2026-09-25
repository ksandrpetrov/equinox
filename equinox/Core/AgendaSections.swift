import Foundation

enum AgendaSections {
    /// Header offsets are relative to the top of the agenda viewport. A pinned
    /// header owns the visible events until the next header reaches the top.
    static func topVisibleDate(headerOffsets: [CalendarDate: Double]) -> CalendarDate? {
        let offsets = headerOffsets.filter { $0.key.isValid && $0.value.isFinite }
        let preceding = offsets.filter { $0.value <= 0 }.max {
            $0.value == $1.value ? $0.key < $1.key : $0.value < $1.value
        }
        return preceding?.key ?? offsets.min {
            $0.value == $1.value ? $0.key < $1.key : $0.value < $1.value
        }?.key
    }

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
