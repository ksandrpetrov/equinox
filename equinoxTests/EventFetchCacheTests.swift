import XCTest
@testable import EquinoxKit

final class EventFetchCacheTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testMixedFetchInvalidationEvictionAndFilteringMatchReferenceState() throws {
        let first = CalendarDate(year: 2026, monthIndex: 0, day: 1)
        let days = (0..<60).map { first.addingDays($0) }
        var cache = EventFetchCache()
        var loaded = Set<CalendarDate>()
        var expected: [CalendarDate: [DayEvent]] = [:]
        var seed: UInt64 = 0xE901
        func next(_ bound: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int(seed >> 32) % bound
        }

        for iteration in 0..<300 {
            let lower = next(50)
            let upper = lower + next(10)
            let range = Array(days[lower...upper])
            switch next(5) {
            case 0:
                // An external change invalidates coverage, retaining the visible snapshot.
                let obsolete = try XCTUnwrap(cache.prepareFetchRange(first: days[lower], last: days[upper], refetch: true))
                cache.invalidate()
                loaded.removeAll()
                XCTAssertFalse(cache.commitFetch([:], plan: obsolete, calendar: calendar))
            case 1:
                cache.clearEvents()
                loaded.removeAll()
                expected.removeAll()
            case 2:
                cache.retainEvents(inside: [(days[lower], days[upper]), (days[0], days[1])], calendar: calendar)
                let retained = Set(range + Array(days[0...1]))
                loaded.formIntersection(retained)
                expected = expected.filter { retained.contains($0.key) }
            default:
                let force = next(2) == 0
                let plan = cache.prepareFetchRange(first: days[lower], last: days[upper], refetch: force)
                XCTAssertEqual(plan == nil, !force && range.allSatisfy { loaded.contains($0) })
                if let plan {
                    var incoming: [Date: [DayEvent]] = [:]
                    for day in days where day >= plan.fetchStart && day <= plan.fetchEnd {
                        // Empty days also replace previously cached events.
                        let events = next(3) == 0 ? [] : [makeEvent(calendarID: next(2) == 0 ? "work" : "personal", on: day)]
                        if events.isEmpty { expected.removeValue(forKey: day) }
                        else { incoming[day.date(in: calendar)] = events; expected[day] = events }
                        loaded.insert(day)
                    }
                    XCTAssertTrue(cache.commitFetch(incoming, plan: plan, calendar: calendar))
                }
            }
            let selected: Set<String> = next(2) == 0 ? ["work"] : ["work", "personal"]
            cache.applyCalendarFilter(selectedCalendarIDs: selected)
            let visible = expected.compactMapValues { events -> [DayEvent]? in
                let filtered = events.filter { selected.contains($0.calendarIdentifier) }
                return filtered.isEmpty ? nil : filtered
            }
            XCTAssertEqual(cache.selectedCalendarEvents(calendar: calendar), visible, "Iteration \(iteration)")
            for day in days {
                XCTAssertEqual(cache.prepareFetchRange(first: day, last: day, refetch: false) == nil,
                               loaded.contains(day), "Coverage at iteration \(iteration), day \(day)")
            }
        }
    }

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
            slotStartDate: dayStart,
            slotEndDate: dayStart.addingTimeInterval(3600),
            isEventAllDay: false,
            isSlotAllDay: false,
            joinURL: nil,
            calendarIdentifier: calendarID,
            calendarTitle: calendarID,
            calendarColorRed: 1,
            calendarColorGreen: 0,
            calendarColorBlue: 0,
            calendarColorAlpha: 1,
            isRecurring: false,
            allowsContentModifications: true,
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

    func testRefetchPreservesCachedEventsOutsideRequestedRange() {
        var cache = EventFetchCache()
        let first = CalendarDate(year: 2026, monthIndex: 5, day: 10)
        let distant = CalendarDate(year: 2027, monthIndex: 5, day: 10)
        let initialPlan = cache.prepareFetchRange(first: first, last: distant, refetch: false)!
        cache.commitFetch(
            [
                first.date(in: calendar): [makeEvent(calendarID: "first", on: first)],
                distant.date(in: calendar): [makeEvent(calendarID: "distant", on: distant)],
            ],
            plan: initialPlan,
            calendar: calendar
        )

        let refetchPlan = cache.prepareFetchRange(first: distant, last: distant, refetch: true)!
        cache.commitFetch([:], plan: refetchPlan, calendar: calendar)

        XCTAssertNotNil(cache.eventsForDate[first.date(in: calendar)])
        XCTAssertNil(cache.eventsForDate[distant.date(in: calendar)])
    }

    func testRetainEventsKeepsPrimaryAndTodayRangesOnly() {
        var cache = EventFetchCache()
        let today = CalendarDate(year: 2026, monthIndex: 5, day: 10)
        let primary = CalendarDate(year: 2027, monthIndex: 5, day: 10)
        let stale = CalendarDate(year: 2025, monthIndex: 5, day: 10)
        let plan = cache.prepareFetchRange(first: stale, last: primary, refetch: false)!
        cache.commitFetch(
            [today, primary, stale].reduce(into: [Date: [DayEvent]]()) { result, date in
                result[date.date(in: calendar)] = [makeEvent(calendarID: "\(date.julian)", on: date)]
            },
            plan: plan,
            calendar: calendar
        )

        cache.retainEvents(
            inside: [(first: primary, last: primary), (first: today, last: today)],
            calendar: calendar
        )

        XCTAssertNotNil(cache.eventsForDate[today.date(in: calendar)])
        XCTAssertNotNil(cache.eventsForDate[primary.date(in: calendar)])
        XCTAssertNil(cache.eventsForDate[stale.date(in: calendar)])
        XCTAssertNil(cache.prepareFetchRange(first: today, last: today, refetch: false))
        XCTAssertNotNil(cache.prepareFetchRange(first: stale, last: stale, refetch: false))
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

    func testClearEventsAlsoClearsStaleFetchError() {
        var cache = EventFetchCache()
        cache.lastFetchError = "stale"

        cache.clearEvents()

        XCTAssertNil(cache.lastFetchError)
    }

    func testInvalidationRejectsSuspendedFetchWithoutLosingDisplayedEvents() throws {
        var cache = EventFetchCache()
        let date = CalendarDate(year: 2026, monthIndex: 5, day: 10)
        let plan = try XCTUnwrap(cache.prepareFetchRange(first: date, last: date, refetch: false))
        let key = date.date(in: calendar)
        cache.commitFetch([key: [makeEvent(calendarID: "work", on: date)]], plan: plan, calendar: calendar)
        cache.invalidate()

        XCTAssertFalse(cache.commitFetch([:], plan: plan, calendar: calendar))
        XCTAssertEqual(cache.eventsForDate[key]?.count, 1)
        XCTAssertNotNil(cache.prepareFetchRange(first: date, last: date, refetch: false))
    }

    func testRevokedAccessCannotBeRepopulatedBySuspendedFetch() throws {
        var cache = EventFetchCache()
        let date = CalendarDate(year: 2026, monthIndex: 5, day: 10)
        let plan = try XCTUnwrap(cache.prepareFetchRange(first: date, last: date, refetch: false))
        cache.clearEvents()
        XCTAssertFalse(cache.commitFetch(
            [date.date(in: calendar): [makeEvent(calendarID: "work", on: date)]],
            plan: plan, calendar: calendar
        ))
        XCTAssertTrue(cache.eventsForDate.isEmpty)
    }

    func testRetainingRangeDoesNotMarkUnfetchedDaysAsLoaded() throws {
        var cache = EventFetchCache()
        let first = CalendarDate(year: 2026, monthIndex: 5, day: 10)
        let last = first.addingDays(10)
        let plan = try XCTUnwrap(cache.prepareFetchRange(first: first, last: first, refetch: false))
        cache.commitFetch([:], plan: plan, calendar: calendar)
        cache.retainEvents(inside: [(first, last)], calendar: calendar)
        XCTAssertNil(cache.prepareFetchRange(first: first, last: first, refetch: false))
        XCTAssertEqual(cache.prepareFetchRange(first: first, last: last, refetch: false)?.fetchStart, first.addingDays(1))
    }

    func testInvalidRangesAreRejected() {
        let cache = EventFetchCache()
        let date = CalendarDate.minimumSupported
        for refetch in [false, true] {
            XCTAssertNil(cache.prepareFetchRange(first: date.addingDays(1), last: date, refetch: refetch))
            XCTAssertNil(cache.prepareFetchRange(first: date.addingDays(-1), last: date, refetch: refetch))
        }
    }
}
