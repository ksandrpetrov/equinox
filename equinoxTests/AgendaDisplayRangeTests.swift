import XCTest
@testable import equinox

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
