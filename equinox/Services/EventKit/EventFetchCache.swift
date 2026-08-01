import Foundation

/// Incremental EventKit fetch cache and selected-calendar filtering for `CalendarStore`.
struct EventFetchCache {
    struct FetchPlan: Equatable {
        let fetchStart: CalendarDate
        let fetchEnd: CalendarDate
        let isRefetch: Bool
    }

    var eventsForDate: [Date: [DayEvent]] = [:]
    private(set) var selectedCalendarEventsByDate: [Date: [DayEvent]] = [:]
    private var previouslyFetchedJulians = IndexSet()
    var lastFetchError: String?

    func selectedCalendarEvents(calendar: Calendar) -> [CalendarDate: [DayEvent]] {
        var result: [CalendarDate: [DayEvent]] = [:]
        for (date, events) in selectedCalendarEventsByDate {
            result[CalendarDate(date: date, calendar: calendar)] = events
        }
        return result
    }

    mutating func clearEvents() {
        previouslyFetchedJulians = IndexSet()
        eventsForDate = [:]
        selectedCalendarEventsByDate = [:]
    }

    /// Plans an inclusive calendar-day fetch without changing the last successful snapshot.
    func prepareFetchRange(first: CalendarDate, last: CalendarDate, refetch: Bool) -> FetchPlan? {
        if refetch {
            return FetchPlan(fetchStart: first, fetchEnd: last, isRefetch: true)
        }

        let dateRange = first.julian..<(last.julian + 1)
        if previouslyFetchedJulians.contains(integersIn: dateRange) {
            return nil
        }

        var notYetFetchedDates = IndexSet()
        for julian in first.julian...last.julian {
            if !previouslyFetchedJulians.contains(julian) {
                notYetFetchedDates.insert(julian)
            }
        }

        var fetchStart = first
        var fetchEnd = last
        if let firstJulian = notYetFetchedDates.first, let lastJulian = notYetFetchedDates.last {
            fetchStart = CalendarDate(julian: firstJulian)
            fetchEnd = CalendarDate(julian: lastJulian)
        }

        return FetchPlan(fetchStart: fetchStart, fetchEnd: fetchEnd, isRefetch: false)
    }

    mutating func commitFetch(
        _ newEventsForDate: [Date: [DayEvent]],
        plan: FetchPlan,
        calendar: Calendar
    ) {
        if plan.isRefetch {
            eventsForDate = newEventsForDate
            previouslyFetchedJulians = IndexSet()
        } else {
            let datesToReplace = eventsForDate.keys.filter { date in
                let calendarDate = CalendarDate(date: date, calendar: calendar)
                return calendarDate >= plan.fetchStart && calendarDate <= plan.fetchEnd
            }
            for date in datesToReplace {
                eventsForDate.removeValue(forKey: date)
            }
            eventsForDate.merge(newEventsForDate) { _, new in new }
        }

        previouslyFetchedJulians.insert(
            integersIn: plan.fetchStart.julian..<(plan.fetchEnd.julian + 1)
        )
        lastFetchError = nil
    }

    mutating func applyCalendarFilter(selectedCalendarIDs: Set<String>) {
        var filtered: [Date: [DayEvent]] = [:]
        for (date, events) in eventsForDate {
            for event in events where selectedCalendarIDs.contains(event.calendarIdentifier) {
                if filtered[date] == nil {
                    filtered[date] = []
                }
                filtered[date]?.append(event)
            }
        }
        selectedCalendarEventsByDate = filtered
    }
}
