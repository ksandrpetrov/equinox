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

        let plan = cache.prepareFetchRange(first: first, last: last, refetch: false)
        XCTAssertNotNil(plan)
        cache.commitFetch([:], plan: plan!, calendar: calendar)
        XCTAssertNil(cache.prepareFetchRange(first: first, last: last, refetch: false))
    }

    func testUncommittedFetchRangeRemainsEligibleForRetry() {
        let cache = EventFetchCache()
        let first = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let last = CalendarDate(year: 2026, monthIndex: 5, day: 7)

        XCTAssertNotNil(cache.prepareFetchRange(first: first, last: last, refetch: false))
        XCTAssertNotNil(cache.prepareFetchRange(first: first, last: last, refetch: false))
    }

    func testPrepareRefetchKeepsLastSuccessfulSnapshotUntilCommit() {
        var cache = EventFetchCache()
        let first = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let last = CalendarDate(year: 2026, monthIndex: 5, day: 7)
        let dayStart = first.date(in: calendar)
        let oldEvent = makeEvent(calendarID: "old", on: first)

        let initialPlan = cache.prepareFetchRange(first: first, last: last, refetch: false)!
        cache.commitFetch([dayStart: [oldEvent]], plan: initialPlan, calendar: calendar)

        let refetchPlan = cache.prepareFetchRange(first: first, last: last, refetch: true)!
        XCTAssertEqual(cache.eventsForDate[dayStart]?.map(\.calendarIdentifier), ["old"])

        cache.commitFetch([:], plan: refetchPlan, calendar: calendar)
        XCTAssertNil(cache.eventsForDate[dayStart])
    }

    func testPrepareFetchRangeExtendsPartiallyFetchedRange() {
        var cache = EventFetchCache()
        let weekStart = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let weekMid = CalendarDate(year: 2026, monthIndex: 5, day: 3)
        let weekEnd = CalendarDate(year: 2026, monthIndex: 5, day: 7)

        let firstFetch = cache.prepareFetchRange(first: weekStart, last: weekMid, refetch: false)
        XCTAssertEqual(firstFetch?.fetchStart, weekStart)
        XCTAssertEqual(firstFetch?.fetchEnd, weekMid)
        cache.commitFetch([:], plan: firstFetch!, calendar: calendar)

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

        let initialPlan = cache.prepareFetchRange(first: date, last: date, refetch: false)!
        cache.commitFetch([dayStart: [oldEvent]], plan: initialPlan, calendar: calendar)
        let refetchPlan = cache.prepareFetchRange(first: date, last: date, refetch: true)!
        cache.commitFetch([dayStart: [newEvent]], plan: refetchPlan, calendar: calendar)

        XCTAssertEqual(cache.eventsForDate[dayStart]?.map(\.calendarIdentifier), ["new"])
    }

    func testApplyCalendarFilterKeepsOnlySelectedCalendars() {
        var cache = EventFetchCache()
        let date = CalendarDate(year: 2026, monthIndex: 5, day: 10)
        let dayStart = date.date(in: calendar)
        let plan = cache.prepareFetchRange(first: date, last: date, refetch: false)!
        cache.commitFetch([
            dayStart: [
                makeEvent(calendarID: "work", on: date),
                makeEvent(calendarID: "personal", on: date),
            ],
        ], plan: plan, calendar: calendar)

        cache.applyCalendarFilter(selectedCalendarIDs: ["work"])

        XCTAssertEqual(cache.selectedCalendarEvents(calendar: calendar)[date]?.map(\.calendarIdentifier), ["work"])
    }

    func testSelectedCalendarEventsMapsDateKeysToCalendarDate() {
        var cache = EventFetchCache()
        let date = CalendarDate(year: 2026, monthIndex: 5, day: 15)
        let dayStart = date.date(in: calendar)
        let plan = cache.prepareFetchRange(first: date, last: date, refetch: false)!
        cache.commitFetch(
            [dayStart: [makeEvent(calendarID: "work", on: date)]],
            plan: plan,
            calendar: calendar
        )
        cache.applyCalendarFilter(selectedCalendarIDs: ["work"])

        let result = cache.selectedCalendarEvents(calendar: calendar)
        XCTAssertEqual(result.keys.sorted { $0.julian < $1.julian }, [date])
    }
}
