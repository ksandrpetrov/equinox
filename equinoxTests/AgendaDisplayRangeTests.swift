import XCTest
@testable import EquinoxKit

final class AgendaDisplayRangeTests: XCTestCase {
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
    var eventsByDate: [CalendarDate: [DayEvent]] = [:]
    var synchronizedSelections: [CalendarDate] = []
    var lastCommittedRange: (first: CalendarDate, last: CalendarDate)?

    init(today: CalendarDate) {
        todayDate = today
        selectedDate = today
    }

    func events(for date: CalendarDate) -> [DayEvent] { [] }

    func syncSelectionFromAgendaScroll(_ date: CalendarDate) {
        synchronizedSelections.append(date)
        selectedDate = date
    }

    func updateAgendaVisibleRange(first: CalendarDate, last: CalendarDate) {
        lastCommittedRange = (first, last)
    }
}
