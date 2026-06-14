import XCTest
@testable import equinox

final class EventFetchRangeTests: XCTestCase {
    func testFetchRangeExtendsForAgendaBounds() {
        let gridFirst = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let gridLast = CalendarDate(year: 2026, monthIndex: 5, day: 30)
        let agendaFirst = CalendarDate(year: 2026, monthIndex: 4, day: 20)
        let agendaLast = CalendarDate(year: 2026, monthIndex: 6, day: 10)

        let range = EventFetchRange.range(
            coveringGridFrom: gridFirst,
            through: gridLast,
            agendaFirst: agendaFirst,
            agendaLast: agendaLast
        )
        XCTAssertEqual(range.first, agendaFirst)
        XCTAssertEqual(range.last, agendaLast)
    }

    func testFetchRangeUsesGridWhenAgendaInsideGrid() {
        let gridFirst = CalendarDate(year: 2026, monthIndex: 5, day: 5)
        let gridLast = CalendarDate(year: 2026, monthIndex: 5, day: 30)
        let agendaFirst = CalendarDate(year: 2026, monthIndex: 5, day: 10)
        let agendaLast = CalendarDate(year: 2026, monthIndex: 5, day: 12)

        let range = EventFetchRange.range(
            coveringGridFrom: gridFirst,
            through: gridLast,
            agendaFirst: agendaFirst,
            agendaLast: agendaLast
        )
        XCTAssertEqual(range.first, gridFirst)
        XCTAssertEqual(range.last, gridLast)
    }

    func testFetchRangeNoAgendaBoundsReturnsGridOnly() {
        let gridFirst = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let gridLast = CalendarDate(year: 2026, monthIndex: 5, day: 30)

        let range = EventFetchRange.range(
            coveringGridFrom: gridFirst,
            through: gridLast,
            agendaFirst: nil,
            agendaLast: nil
        )
        XCTAssertEqual(range.first, gridFirst)
        XCTAssertEqual(range.last, gridLast)
    }
}
