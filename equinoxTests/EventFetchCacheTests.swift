import XCTest
@testable import equinox

final class EventFetchCacheTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func makeEvent(calendarID: String, on date: CalendarDate) -> DayEvent {
        let dayStart = date.date(in: calendar)
        return DayEvent(
            id: "\(calendarID)-\(date.julian)",
            eventIdentifier: "e-\(calendarID)",
            calendarItemIdentifier: "ci-\(calendarID)",
            title: "Event",
            location: nil,
            notes: nil,
            url: nil,
            startDate: dayStart,
            endDate: dayStart.addingTimeInterval(3600),
            isEventAllDay: false,
            isFirstDayOfSpan: true,
            isLastDayOfSpan: true,
            isSlotAllDay: false,
            joinURL: nil,
            calendarIdentifier: calendarID,
            calendarTitle: calendarID,
            calendarColorRed: 1,
            calendarColorGreen: 0,
            calendarColorBlue: 0,
            calendarColorAlpha: 1,
            allowsContentModifications: true,
            hasAttendees: false,
            participationStatus: nil
        )
    }

    func testPrepareFetchRangeReturnsNilWhenAlreadyFetched() {
        var cache = EventFetchCache()
        let first = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let last = CalendarDate(year: 2026, monthIndex: 5, day: 7)

        XCTAssertNotNil(cache.prepareFetchRange(first: first, last: last, refetch: false))
        XCTAssertNil(cache.prepareFetchRange(first: first, last: last, refetch: false))
    }

    func testPrepareFetchRangeRefetchResetsCache() {
        var cache = EventFetchCache()
        let first = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let last = CalendarDate(year: 2026, monthIndex: 5, day: 7)

        XCTAssertNotNil(cache.prepareFetchRange(first: first, last: last, refetch: false))
        XCTAssertNil(cache.prepareFetchRange(first: first, last: last, refetch: false))

        XCTAssertNotNil(cache.prepareFetchRange(first: first, last: last, refetch: true))
    }

    func testPrepareFetchRangeExtendsPartiallyFetchedRange() {
        var cache = EventFetchCache()
        let weekStart = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let weekMid = CalendarDate(year: 2026, monthIndex: 5, day: 3)
        let weekEnd = CalendarDate(year: 2026, monthIndex: 5, day: 7)

        let firstFetch = cache.prepareFetchRange(first: weekStart, last: weekMid, refetch: false)
        XCTAssertEqual(firstFetch?.fetchStart, weekStart)
        XCTAssertEqual(firstFetch?.fetchEnd, weekMid)

        let secondFetch = cache.prepareFetchRange(first: weekStart, last: weekEnd, refetch: false)
        XCTAssertEqual(secondFetch?.fetchStart, weekMid.addingDays(1))
        XCTAssertEqual(secondFetch?.fetchEnd, weekEnd)
    }

    func testMergeEventsOverwritesExistingDates() {
        var cache = EventFetchCache()
        let date = CalendarDate(year: 2026, monthIndex: 5, day: 10)
        let dayStart = date.date(in: calendar)
        let oldEvent = makeEvent(calendarID: "old", on: date)
        let newEvent = makeEvent(calendarID: "new", on: date)

        cache.mergeEvents([dayStart: [oldEvent]])
        cache.mergeEvents([dayStart: [newEvent]])

        XCTAssertEqual(cache.eventsForDate[dayStart]?.map(\.calendarIdentifier), ["new"])
    }

    func testApplyCalendarFilterKeepsOnlySelectedCalendars() {
        var cache = EventFetchCache()
        let date = CalendarDate(year: 2026, monthIndex: 5, day: 10)
        let dayStart = date.date(in: calendar)
        cache.mergeEvents([
            dayStart: [
                makeEvent(calendarID: "work", on: date),
                makeEvent(calendarID: "personal", on: date),
            ],
        ])

        cache.applyCalendarFilter(selectedCalendarIDs: ["work"])

        XCTAssertEqual(cache.selectedCalendarEvents(calendar: calendar)[date]?.map(\.calendarIdentifier), ["work"])
    }

    func testSelectedCalendarEventsMapsDateKeysToCalendarDate() {
        var cache = EventFetchCache()
        let date = CalendarDate(year: 2026, monthIndex: 5, day: 15)
        let dayStart = date.date(in: calendar)
        cache.mergeEvents([dayStart: [makeEvent(calendarID: "work", on: date)]])
        cache.applyCalendarFilter(selectedCalendarIDs: ["work"])

        let result = cache.selectedCalendarEvents(calendar: calendar)
        XCTAssertEqual(result.keys.sorted { $0.julian < $1.julian }, [date])
    }
}
