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
        let selected = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let initial = AgendaDisplayRange.initialRange(anchor: selected)
        let farPast = selected.addingDays(-100)
        let expanded = AgendaDisplayRange.rangeCovering(
            date: farPast,
            first: initial.first,
            last: initial.last
        )
        let expected = AgendaDisplayRange.initialRange(anchor: farPast)
        XCTAssertEqual(expanded.first, expected.first)
        XCTAssertEqual(expanded.last, expected.last)
    }

    func testShouldExtendWhenNearBoundary() {
        let first = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let nearPast = first.addingDays(AgendaDisplayRange.extendThresholdDays - 1)
        XCTAssertTrue(AgendaDisplayRange.shouldExtendPast(visible: nearPast, rangeFirst: first))

        let last = CalendarDate(year: 2026, monthIndex: 5, day: 30)
        let nearFuture = last.addingDays(-(AgendaDisplayRange.extendThresholdDays - 1))
        XCTAssertTrue(AgendaDisplayRange.shouldExtendFuture(visible: nearFuture, rangeLast: last))
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
        let now = Date()
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
        let coordinator = AgendaScrollCoordinator()
        coordinator.scrollToFocus(events: state.events)
        XCTAssertEqual(coordinator.requestedTarget, .event(id: ongoing.id), "Initial presentation still focuses the current meeting")

        state.goToNextMonth()
        coordinator.scrollToFocus(events: state.events)
        state.goToToday()
        coordinator.scheduleScrollToFocus(events: state.events)
        try await Task.sleep(for: AgendaFocus.navigationCoalescingDelay + .milliseconds(50))

        let header = AgendaScrollTarget.day(julian: today.julian)
        XCTAssertEqual(coordinator.requestedTarget, header)
        XCTAssertEqual(coordinator.scrolledTarget, header)

        coordinator.scrolledTarget = .event(id: ongoing.id)
        state.goToToday()
        coordinator.scheduleScrollToFocus(events: state.events)
        try await Task.sleep(for: AgendaFocus.navigationCoalescingDelay + .milliseconds(50))
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
        let coordinator = AgendaScrollCoordinator()
        state.panel.isPanelVisible = true
        state.goToToday()
        coordinator.scrollToFocus(events: state.events)
        let header = AgendaScrollTarget.day(julian: today.julian)
        XCTAssertEqual(coordinator.requestedTarget, header)

        let events = [today: [fixture.event(start: Date().addingTimeInterval(1800))]]
        fixture.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: events) }
        await state.events.resetCalendarSelection()
        coordinator.scrollToFocus(events: state.events)
        XCTAssertEqual(coordinator.requestedTarget, header, "Loading an upcoming meeting must not move the requested day header")
    }

    func testTodayFocusDoesNotJumpToTomorrowsMeetingWithTodayStillSelected() throws {
        let fixture = try CalendarTestContext()
        defer { fixture.cleanUp() }
        let now = Date()
        let today = CalendarDate.today(calendar: fixture.appState.calendar)
        let context = SparseAgendaContext(today: today)
        context.eventsByDate = [
            today: [fixture.event(start: now.addingTimeInterval(-7200))],
            today.addingDays(1): [fixture.event(start: now.addingTimeInterval(86400))]
        ]
        let coordinator = AgendaScrollCoordinator()
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
        let coordinator = AgendaScrollCoordinator()
        for month in 1...24 {
            context.selectedDate = today.addingMonths(month)
            context.agendaScrollToken += 1
            coordinator.scheduleScrollToFocus(events: context)
        }
        XCTAssertNil(coordinator.requestedTarget)
        try await Task.sleep(for: AgendaFocus.navigationCoalescingDelay + .milliseconds(50))
        let target = AgendaScrollTarget.day(julian: today.addingMonths(24).julian)
        XCTAssertEqual(coordinator.requestedTarget, target)
        XCTAssertEqual(coordinator.scrolledTarget, target)

        context.selectedDate = today.addingMonths(25)
        context.agendaScrollToken += 1
        coordinator.scheduleScrollToFocus(events: context)
        coordinator.updateVisibleDate(today.addingDays(2), events: context)
        coordinator.beginUserScroll(events: context)
        try await Task.sleep(for: AgendaFocus.navigationCoalescingDelay + .milliseconds(50))
        XCTAssertEqual(context.selectedDate, today.addingDays(2))
        XCTAssertEqual(coordinator.requestedTarget, target, "A delayed navigation must not interrupt a new user gesture")
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
        coordinator.scrollToFocus(events: context)
        XCTAssertNil(coordinator.scrolledTarget)
        let drained = expectation(description: "Repeated focus assigned")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertEqual(coordinator.scrolledTarget, .day(julian: context.selectedDate.julian))
    }

    func testSparseAgendaBoundaryExtendsWithoutChangingSelection() {
        let today = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let context = SparseAgendaContext(today: today)
        let coordinator = AgendaScrollCoordinator()
        coordinator.bootstrapRangeIfNeeded(anchor: today)
        let initial = coordinator.displayRange(anchor: today)
        let target = AgendaScrollTarget.boundary(julian: initial.last.julian)
        coordinator.scrolledTarget = target

        coordinator.handleAgendaScroll(to: target, anchor: today, events: context)
        coordinator.commitScrollSettle(events: context)

        let extended = coordinator.displayRange(anchor: today)
        XCTAssertGreaterThan(extended.last, initial.last)
        XCTAssertTrue(context.synchronizedSelections.isEmpty)
        XCTAssertEqual(context.lastCommittedRange?.last, extended.last)
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
        lastCommittedRange = (first, last)
    }
}
