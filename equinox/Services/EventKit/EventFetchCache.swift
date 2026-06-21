import Foundation

/// Incremental EventKit fetch cache and selected-calendar filtering for `CalendarStore`.
struct EventFetchCache {
    var eventsForDate: [Date: [DayEvent]] = [:]
    private(set) var selectedCalendarEventsByDate: [Date: [DayEvent]] = [:]
    private var previouslyFetchedJulians = IndexSet()
    var lastFetchedFirst = CalendarDate(year: 1583, monthIndex: 0, day: 1)
    var lastFetchedLast = CalendarDate(year: 1583, monthIndex: 0, day: 1)
    var hasFetchedRange = false
    var isFetchingEvents = false
    var lastFetchError: String?

    mutating func selectedCalendarEvents(calendar: Calendar) -> [CalendarDate: [DayEvent]] {
        var result: [CalendarDate: [DayEvent]] = [:]
        for (date, events) in selectedCalendarEventsByDate {
            result[CalendarDate(date: date, calendar: calendar)] = events
        }
        return result
    }

    func events(on date: CalendarDate, calendar: Calendar) -> [DayEvent] {
        selectedCalendarEventsByDate[date.date(in: calendar)] ?? []
    }

    mutating func resetForRefetch() {
        previouslyFetchedJulians = IndexSet()
        eventsForDate = [:]
    }

    /// Returns false when the julian range was already fetched.
    mutating func prepareFetchRange(first: CalendarDate, last: CalendarDate, refetch: Bool) -> (fetchStart: CalendarDate, fetchEnd: CalendarDate)? {
        if refetch {
            resetForRefetch()
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

        previouslyFetchedJulians.insert(integersIn: dateRange)
        return (fetchStart, fetchEnd)
    }

    mutating func mergeEvents(_ newEventsForDate: [Date: [DayEvent]]) {
        eventsForDate.merge(newEventsForDate) { _, new in new }
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
