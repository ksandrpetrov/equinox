import XCTest
@testable import EquinoxKit

final class AgendaDisplayRangeTests: XCTestCase {
    func testRepeatedMonthlyNavigationDoesNotAccumulateYearsOfAgendaContent() {
        let start = CalendarDate(year: 2026, monthIndex: 0, day: 14)
        var range = AgendaDisplayRange.initialRange(anchor: start)
        for month in 1...36 {
            let destination = start.addingMonths(month)
            range = AgendaDisplayRange.rangeCovering(date: destination, first: range.first, last: range.last)
            XCTAssertLessThanOrEqual(range.last.compare(range.first), 120)
            XCTAssertTrue(range.first <= destination && destination <= range.last)
        }
    }

    func testNavigationWithinManuallyExtendedAgendaPreservesScrollContent() {
        let today = CalendarDate(year: 2026, monthIndex: 8, day: 12)
        let first = today.addingDays(-180)
        let last = today.addingDays(180)
        let range = AgendaDisplayRange.rangeCovering(date: today.addingDays(30), first: first, last: last)
        XCTAssertEqual(range.first, first)
        XCTAssertEqual(range.last, last)
    }

    func testInitialRangeAnchorsOnTodayWithPastAndFuture() {
        let today = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let range = AgendaDisplayRange.initialRange(anchor: today)
        XCTAssertEqual(range.first, today.addingDays(-AgendaDisplayRange.initialPastDays))
        XCTAssertEqual(range.last, today.addingDays(AgendaDisplayRange.initialFutureDays))
    }

    func testRangeCoveringExpandsPastAndFuture() {
        let anchor = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        // A one-day window isolates the distance threshold from the total span limit.
        let cases: [(distance: Int, first: Int, last: Int)] = [
            (-61, -75, -16), (-60, -60, 0), (-31, -60, 0), (-30, -30, 0), (-1, -30, 0),
            (0, 0, 0), (1, 0, 30), (30, 0, 30), (31, 0, 60), (60, 0, 60), (61, 47, 106),
        ]
        for item in cases {
            let range = AgendaDisplayRange.rangeCovering(
                date: anchor.addingDays(item.distance), first: anchor, last: anchor
            )
            XCTAssertEqual(range.first, anchor.addingDays(item.first), "Distance: \(item.distance)")
            XCTAssertEqual(range.last, anchor.addingDays(item.last), "Distance: \(item.distance)")
        }
    }

    func testNavigationReanchorsOnlyWhenExpandedSpanExceeds119Days() {
        let first = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        for span in [89, 90] {
            let range = AgendaDisplayRange.rangeCovering(
                date: first.addingDays(-1), first: first, last: first.addingDays(span)
            )
            XCTAssertEqual(range.first, first.addingDays(span == 89 ? -30 : -15))
            XCTAssertEqual(range.last, first.addingDays(span == 89 ? 89 : 44))
        }
    }

    func testInvalidSelectionAndExistingEndpointsPreserveRange() {
        let first = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let last = first.addingDays(30)
        for date in [first, last, CalendarDate.minimumSupported.addingDays(-1), .maximumSupported.addingDays(1)] {
            let range = AgendaDisplayRange.rangeCovering(date: date, first: first, last: last)
            XCTAssertEqual(range.first, first)
            XCTAssertEqual(range.last, last)
        }
    }

    func testShouldExtendWhenNearBoundary() {
        let first = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let last = CalendarDate(year: 2026, monthIndex: 5, day: 30)
        for distance in [0, 9, 10, 11] {
            XCTAssertEqual(AgendaDisplayRange.shouldExtendPast(visible: first.addingDays(distance), rangeFirst: first), distance < 10)
            XCTAssertEqual(AgendaDisplayRange.shouldExtendFuture(visible: last.addingDays(-distance), rangeLast: last), distance < 10)
        }
    }

    func testFarJumpDoesNotCreateCenturySpanningFetchRange() {
        let today = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let destination = CalendarDate(year: 3333, monthIndex: 11, day: 31)
        let initial = AgendaDisplayRange.initialRange(anchor: today)
        let range = AgendaDisplayRange.rangeCovering(
            date: destination,
            first: initial.first,
            last: initial.last
        )

        let expected = AgendaDisplayRange.initialRange(anchor: destination)
        XCTAssertEqual(range.first, expected.first)
        XCTAssertEqual(range.last, expected.last)
        XCTAssertEqual(range.last, CalendarDate.maximumSupported)
        XCTAssertLessThanOrEqual(range.last.compare(range.first), AgendaDisplayRange.initialPastDays + AgendaDisplayRange.initialFutureDays)
    }

    func testInitialRangeClampsAtSupportedBoundaries() {
        let minimum = AgendaDisplayRange.initialRange(anchor: CalendarDate.minimumSupported)
        XCTAssertEqual(minimum.first, CalendarDate.minimumSupported)

        let maximum = AgendaDisplayRange.initialRange(anchor: CalendarDate.maximumSupported)
        XCTAssertEqual(maximum.last, CalendarDate.maximumSupported)
    }
}

@MainActor
final class AgendaScrollBoundaryTests: XCTestCase {
    func testTodayButtonScrollsToDayHeaderInsteadOfOngoingMeeting() async throws {
        let fixture = try CalendarTestContext()
        defer { fixture.cleanUp() }
        let state = fixture.appState
        let today = state.events.todayDate
        let now = fixture.now
        let ongoing = fixture.event(start: now.addingTimeInterval(-300))
        let events = [today: [
            fixture.event(start: today.date(in: state.calendar), isAllDay: true),
            fixture.event(start: now.addingTimeInterval(-7200)),
            ongoing,
            fixture.event(start: now.addingTimeInterval(1800))
        ]]
        fixture.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: events) }
        await fixture.finishInitialization()
        state.panel.isPanelVisible = true
        var delay = ManualNavigationDelay()
        defer { delay.resumeAll() }
        let coordinator = AgendaScrollCoordinator(now: { fixture.now }, navigationDelay: { try await delay.wait() })
        coordinator.scrollToFocus(events: state.events)
        XCTAssertEqual(coordinator.requestedTarget, .event(id: ongoing.id), "Initial presentation still focuses the current meeting")

        state.goToNextMonth()
        coordinator.scrollToFocus(events: state.events)
        state.goToToday()
        coordinator.scheduleScrollToFocus(events: state.events)
        await fulfillment(of: [delay.suspended], timeout: 2)
        delay.resumeAll()
        await fulfillment(of: [delay.completed], timeout: 2)

        let header = AgendaScrollTarget.day(julian: today.julian)
        XCTAssertEqual(coordinator.requestedTarget, header)
        XCTAssertEqual(coordinator.scrolledTarget, header)

        delay = ManualNavigationDelay()
        coordinator.scrolledTarget = .event(id: ongoing.id)
        state.goToToday()
        coordinator.scheduleScrollToFocus(events: state.events)
        await fulfillment(of: [delay.suspended], timeout: 2)
        delay.resumeAll()
        await fulfillment(of: [delay.completed], timeout: 2)
        XCTAssertEqual(coordinator.scrolledTarget, header, "Today must return to the header even when today is already selected")

        state.selectDate(today)
        coordinator.scrollToFocus(events: state.events)
        XCTAssertEqual(coordinator.requestedTarget, .event(id: ongoing.id), "A later calendar selection uses its usual focus")
    }

    func testTodayHeaderRemainsTargetWhenMeetingsLoadLater() async throws {
        let fixture = try CalendarTestContext()
        defer { fixture.cleanUp() }
        await fixture.finishInitialization()
        let state = fixture.appState
        let today = state.events.todayDate
        let coordinator = AgendaScrollCoordinator(now: { fixture.now })
        state.panel.isPanelVisible = true
        state.goToToday()
        coordinator.scrollToFocus(events: state.events)
        let header = AgendaScrollTarget.day(julian: today.julian)
        XCTAssertEqual(coordinator.requestedTarget, header)

        let events = [today: [fixture.event(start: fixture.now.addingTimeInterval(1800))]]
        fixture.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: events) }
        await state.events.resetCalendarSelection()
        coordinator.scrollToFocus(events: state.events)
        XCTAssertEqual(coordinator.requestedTarget, header, "Loading an upcoming meeting must not move the requested day header")
    }

    func testTodayFocusDoesNotJumpToTomorrowsMeetingWithTodayStillSelected() throws {
        let fixture = try CalendarTestContext()
        defer { fixture.cleanUp() }
        let now = fixture.now
        let today = fixture.appState.events.todayDate
        let context = SparseAgendaContext(today: today)
        context.eventsByDate = [
            today: [fixture.event(start: now.addingTimeInterval(-7200))],
            today.addingDays(1): [fixture.event(start: now.addingTimeInterval(86400))]
        ]
        let coordinator = AgendaScrollCoordinator(now: { fixture.now })
        coordinator.scrollToFocus(events: context)
        XCTAssertEqual(coordinator.scrolledTarget, .day(julian: today.julian))
        XCTAssertEqual(context.selectedDate, today)

        let ongoing = fixture.event(start: now.addingTimeInterval(-300))
        context.eventsByDate[today] = [ongoing]
        coordinator.scrollToFocus(events: context)
        XCTAssertEqual(coordinator.scrolledTarget, .event(id: ongoing.id))
    }

    func testRapidNavigationCoalescesAgendaFocusAndUserGestureCanCancelIt() async throws {
        let today = CalendarDate(year: 2026, monthIndex: 8, day: 12)
        let context = SparseAgendaContext(today: today)
        var delay = ManualNavigationDelay(requests: 24)
        defer { delay.resumeAll() }
        let coordinator = AgendaScrollCoordinator(navigationDelay: { try await delay.wait() })
        for month in 1...24 {
            context.selectedDate = today.addingMonths(month)
            context.agendaScrollToken += 1
            coordinator.scheduleScrollToFocus(events: context)
        }
        XCTAssertNil(coordinator.requestedTarget)
        await fulfillment(of: [delay.suspended], timeout: 2)
        delay.resumeAll()
        await fulfillment(of: [delay.completed], timeout: 2)
        let target = AgendaScrollTarget.day(julian: today.addingMonths(24).julian)
        XCTAssertEqual(coordinator.requestedTarget, target)
        XCTAssertEqual(coordinator.scrolledTarget, target)
        XCTAssertEqual(context.committedRangeCount, 1, "Coalesced navigation must commit only the final focus")

        delay = ManualNavigationDelay()
        context.selectedDate = today.addingMonths(25)
        context.agendaScrollToken += 1
        coordinator.scheduleScrollToFocus(events: context)
        coordinator.updateVisibleDate(today.addingDays(2), events: context)
        coordinator.beginUserScroll(events: context)
        await fulfillment(of: [delay.suspended], timeout: 2)
        delay.resumeAll()
        await fulfillment(of: [delay.completed], timeout: 2)
        XCTAssertEqual(context.selectedDate, today.addingDays(2))
        XCTAssertEqual(coordinator.requestedTarget, target, "A delayed navigation must not interrupt a new user gesture")
        XCTAssertEqual(context.committedRangeCount, 1, "A cancelled focus must not commit another fetch range")
    }

    func testImmediateFocusCancelsPendingDelayedFocus() async {
        let today = CalendarDate(year: 2026, monthIndex: 8, day: 12)
        let context = SparseAgendaContext(today: today)
        let delay = ManualNavigationDelay()
        defer { delay.resumeAll() }
        let coordinator = AgendaScrollCoordinator(navigationDelay: { try await delay.wait() })
        context.selectedDate = today.addingDays(1)
        coordinator.scheduleScrollToFocus(events: context)
        await fulfillment(of: [delay.suspended], timeout: 2)

        context.selectedDate = today.addingDays(2)
        coordinator.scrollToFocus(events: context)
        let expected = AgendaScrollTarget.day(julian: context.selectedDate.julian)
        XCTAssertEqual(coordinator.scrolledTarget, expected)
        XCTAssertEqual(context.committedRangeCount, 1)

        delay.resumeAll()
        await fulfillment(of: [delay.completed], timeout: 2)
        XCTAssertEqual(context.committedRangeCount, 1, "Immediate focus must cancel the older delayed request")
        XCTAssertEqual(coordinator.scrolledTarget, expected)
    }

    func testSelectionFollowsVisibleHeaderDuringScrollInsteadOfNearestTarget() {
        let today = CalendarDate(year: 2026, monthIndex: 8, day: 30)
        let context = SparseAgendaContext(today: today)
        let coordinator = AgendaScrollCoordinator()
        coordinator.scrolledTarget = .day(julian: today.addingDays(2).julian)
        coordinator.updateVisibleDate(today, events: context)
        coordinator.beginUserScroll(events: context)

        coordinator.updateVisibleDate(today.addingDays(1), events: context)
        XCTAssertEqual(context.selectedDate, today.addingDays(1), "Selection must change before scrolling stops")
        coordinator.commitScrollSettle(events: context)
        XCTAssertEqual(context.selectedDate, today.addingDays(1), "A nearby scroll target must not override the visible header")
        XCTAssertEqual(context.synchronizedSelections, [today, today.addingDays(1)])
        XCTAssertEqual(context.committedRangeCount, 1, "Settling a user scroll must commit its visible range")

        coordinator.updateVisibleDate(today.addingDays(2), events: context)
        XCTAssertEqual(context.selectedDate, today.addingDays(2), "The last geometry update can arrive after the idle phase")
        coordinator.updateVisibleDate(today, events: context)
        XCTAssertEqual(context.selectedDate, today, "Scrolling back across the month boundary must follow the same rule")
    }

    func testProgrammaticFocusDoesNotLetIntermediateHeadersOverrideChosenDay() {
        let today = CalendarDate(year: 2026, monthIndex: 8, day: 12)
        let context = SparseAgendaContext(today: today)
        let coordinator = AgendaScrollCoordinator()
        context.selectedDate = today.addingDays(5)
        coordinator.scrollToFocus(events: context)
        let requestedTarget = coordinator.requestedTarget

        coordinator.updateVisibleDate(today.addingDays(2), events: context)
        coordinator.commitScrollSettle(events: context)
        XCTAssertEqual(context.selectedDate, today.addingDays(5))
        XCTAssertTrue(context.synchronizedSelections.isEmpty)
        XCTAssertEqual(context.committedRangeCount, 1, "Intermediate programmatic scroll geometry must not fetch again")

        coordinator.beginUserScroll(events: context)
        XCTAssertEqual(context.selectedDate, today.addingDays(2), "A user gesture must take over without a timing delay")
        coordinator.scrolledTarget = .day(julian: today.addingDays(3).julian)
        XCTAssertEqual(coordinator.requestedTarget, requestedTarget, "User scrolling must not change the programmatic alignment anchor")
    }

    func testUserScrollCancelsDeferredRepeatedFocus() async {
        let today = CalendarDate(year: 2026, monthIndex: 8, day: 12)
        let context = SparseAgendaContext(today: today)
        let coordinator = AgendaScrollCoordinator()
        coordinator.scrollToFocus(events: context)
        coordinator.scrollToFocus(events: context)
        XCTAssertNil(coordinator.scrolledTarget)
        coordinator.updateVisibleDate(today.addingDays(2), events: context)
        coordinator.beginUserScroll(events: context)

        let drained = expectation(description: "Deferred focus cancelled after user scroll")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)

        XCTAssertNil(coordinator.scrolledTarget)
        XCTAssertEqual(context.selectedDate, today.addingDays(2))
    }

    func testMonthNavigationRejectsStaleScrollGeometryBeforeFocusUpdates() {
        let today = CalendarDate(year: 2026, monthIndex: 8, day: 12)
        let context = SparseAgendaContext(today: today)
        let coordinator = AgendaScrollCoordinator()
        coordinator.updateVisibleDate(today, events: context)
        coordinator.beginUserScroll(events: context)

        let nextMonth = today.addingMonths(1)
        context.selectedDate = nextMonth
        context.agendaScrollToken += 1
        coordinator.updateVisibleDate(today.addingDays(1), events: context)
        coordinator.commitScrollSettle(events: context)

        XCTAssertEqual(context.selectedDate, nextMonth)
    }

    func testNewFocusSupersedesDeferredRepeatScroll() async {
        let today = CalendarDate(year: 2026, monthIndex: 8, day: 12)
        let context = SparseAgendaContext(today: today)
        let coordinator = AgendaScrollCoordinator()
        context.selectedDate = today.addingDays(1)
        coordinator.scrollToFocus(events: context)
        coordinator.scrollToFocus(events: context)
        XCTAssertNil(coordinator.scrolledTarget)
        context.selectedDate = today.addingDays(2)
        coordinator.scrollToFocus(events: context)
        let expected = AgendaScrollTarget.day(julian: context.selectedDate.julian)
        XCTAssertEqual(coordinator.scrolledTarget, expected)

        let drained = expectation(description: "Deferred scroll assignments completed")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)

        XCTAssertEqual(coordinator.scrolledTarget, expected)
        XCTAssertTrue(context.synchronizedSelections.isEmpty)
    }

    func testRepeatedFocusStillScrollsWhenNotSuperseded() async {
        let context = SparseAgendaContext(today: CalendarDate(year: 2026, monthIndex: 8, day: 12))
        let coordinator = AgendaScrollCoordinator()
        coordinator.scrollToFocus(events: context)
        let initialized = coordinator.displayRange(anchor: context.todayDate.addingDays(1))
        XCTAssertEqual(initialized.first, context.todayDate.addingDays(-14))
        XCTAssertEqual(initialized.last, context.todayDate.addingDays(45), "The first focus must initialize a persistent range")
        coordinator.scrollToFocus(events: context)
        XCTAssertNil(coordinator.scrolledTarget)
        let drained = expectation(description: "Repeated focus assigned")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertEqual(coordinator.scrolledTarget, .day(julian: context.selectedDate.julian))
    }

    func testFocusCommitsEachIndependentlyExpandedBoundary() {
        let today = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let cases = [(selected: -15, first: -44, last: 45), (selected: 46, first: -14, last: 75)]
        for item in cases {
            let context = SparseAgendaContext(today: today)
            context.selectedDate = today.addingDays(item.selected)
            let coordinator = AgendaScrollCoordinator()
            coordinator.bootstrapRangeIfNeeded(anchor: today)
            coordinator.scrollToFocus(events: context)

            XCTAssertEqual(context.lastCommittedRange?.first, today.addingDays(item.first), "Selection offset \(item.selected)")
            XCTAssertEqual(context.lastCommittedRange?.last, today.addingDays(item.last), "Selection offset \(item.selected)")
        }
    }

    func testEventScrollTargetsExtendTheirOwnDayAndIgnoreUnknownIDs() async throws {
        let fixture = try CalendarTestContext()
        defer { fixture.cleanUp() }
        await fixture.finishInitialization()
        let today = fixture.appState.events.todayDate
        let past = today.addingDays(-14)
        let future = today.addingDays(45)
        let pastEvent = fixture.event(start: past.date(in: fixture.appState.calendar))
        let futureEvent = fixture.event(start: future.date(in: fixture.appState.calendar))
        let context = SparseAgendaContext(today: today)
        context.eventsByDate = [past: [pastEvent], future: [futureEvent]]
        let cases = [
            (id: pastEvent.id, first: -44, last: 45),
            (id: futureEvent.id, first: -14, last: 75),
            (id: "missing", first: -14, last: 45),
        ]
        for item in cases {
            let coordinator = AgendaScrollCoordinator()
            coordinator.bootstrapRangeIfNeeded(anchor: today)
            coordinator.handleAgendaScroll(to: .event(id: item.id), anchor: today, events: context)

            let range = coordinator.displayRange(anchor: today)
            XCTAssertEqual(range.first, today.addingDays(item.first), item.id)
            XCTAssertEqual(range.last, today.addingDays(item.last), item.id)
        }
    }

    func testSparseAgendaBoundaryExtendsWithoutChangingSelection() {
        let today = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let cases = [(boundary: -14, first: -44, last: 45), (boundary: 45, first: -14, last: 75)]
        for item in cases {
            let context = SparseAgendaContext(today: today)
            let coordinator = AgendaScrollCoordinator()
            coordinator.bootstrapRangeIfNeeded(anchor: today)
            let initial = coordinator.displayRange(anchor: today)
            let nextDayRange = coordinator.displayRange(anchor: today.addingDays(1))
            XCTAssertEqual(nextDayRange.first, initial.first, "An initialized range must survive a change of today")
            XCTAssertEqual(nextDayRange.last, initial.last)
            let target = AgendaScrollTarget.boundary(julian: today.addingDays(item.boundary).julian)
            coordinator.scrolledTarget = target

            coordinator.handleAgendaScroll(to: target, anchor: today, events: context)
            coordinator.commitScrollSettle(events: context)

            let extended = coordinator.displayRange(anchor: today)
            XCTAssertEqual(extended.first, today.addingDays(item.first), "Boundary offset \(item.boundary)")
            XCTAssertEqual(extended.last, today.addingDays(item.last), "Boundary offset \(item.boundary)")
            XCTAssertTrue(context.synchronizedSelections.isEmpty)
            XCTAssertEqual(context.lastCommittedRange?.first, extended.first)
            XCTAssertEqual(context.lastCommittedRange?.last, extended.last)

            coordinator.scrollToFocus(events: context)
            let refocused = coordinator.displayRange(anchor: today)
            XCTAssertEqual(refocused.first, extended.first)
            XCTAssertEqual(refocused.last, extended.last, "Refocusing must preserve days already loaded by scrolling")
        }
    }
}

@MainActor
private final class SparseAgendaContext: AgendaScrollContext {
    let todayDate: CalendarDate
    var selectedDate: CalendarDate
    var agendaScrollToken = 0
    var agendaFocusesDayStart = false
    var eventsByDate: [CalendarDate: [DayEvent]] = [:]
    var synchronizedSelections: [CalendarDate] = []
    var lastCommittedRange: (first: CalendarDate, last: CalendarDate)?
    private(set) var committedRangeCount = 0

    init(today: CalendarDate) {
        todayDate = today
        selectedDate = today
    }

    func events(for date: CalendarDate) -> [DayEvent] { eventsByDate[date] ?? [] }

    func syncSelectionFromAgendaScroll(_ date: CalendarDate) {
        synchronizedSelections.append(date)
        selectedDate = date
    }

    func updateAgendaVisibleRange(first: CalendarDate, last: CalendarDate) {
        committedRangeCount += 1
        lastCommittedRange = (first, last)
    }
}
