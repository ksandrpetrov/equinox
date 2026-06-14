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
        XCTAssertLessThan(expanded.first, initial.first)
        XCTAssertEqual(expanded.last, initial.last)
    }

    func testShouldExtendWhenNearBoundary() {
        let first = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let nearPast = first.addingDays(AgendaDisplayRange.extendThresholdDays - 1)
        XCTAssertTrue(AgendaDisplayRange.shouldExtendPast(visible: nearPast, rangeFirst: first))

        let last = CalendarDate(year: 2026, monthIndex: 5, day: 30)
        let nearFuture = last.addingDays(-(AgendaDisplayRange.extendThresholdDays - 1))
        XCTAssertTrue(AgendaDisplayRange.shouldExtendFuture(visible: nearFuture, rangeLast: last))
    }
}
