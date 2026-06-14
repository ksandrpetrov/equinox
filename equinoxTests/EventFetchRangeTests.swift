import XCTest
@testable import equinox

final class EventFetchRangeTests: XCTestCase {
    func testFetchRangeExtendsForAgendaDays() {
        let gridFirst = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let gridLast = CalendarDate(year: 2026, monthIndex: 5, day: 30)
        let selectedDate = CalendarDate(year: 2026, monthIndex: 5, day: 10)

        let range = EventFetchRange.range(
            coveringGridFrom: gridFirst,
            through: gridLast,
            selectedDate: selectedDate,
            agendaDays: 3
        )
        XCTAssertEqual(range.first, gridFirst)
        XCTAssertEqual(range.last, CalendarDate(year: 2026, monthIndex: 5, day: 12))
    }

    func testFetchRangePullsEarlierSelectedDate() {
        let gridFirst = CalendarDate(year: 2026, monthIndex: 5, day: 5)
        let gridLast = CalendarDate(year: 2026, monthIndex: 5, day: 30)
        let selectedDate = CalendarDate(year: 2026, monthIndex: 5, day: 1)

        let range = EventFetchRange.range(
            coveringGridFrom: gridFirst,
            through: gridLast,
            selectedDate: selectedDate,
            agendaDays: 7
        )
        XCTAssertEqual(range.first, CalendarDate(year: 2026, monthIndex: 4, day: 26))
    }

    func testFetchRangeNoAgendaDaysReturnsGridOnly() {
        let gridFirst = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let gridLast = CalendarDate(year: 2026, monthIndex: 5, day: 30)

        let range = EventFetchRange.range(
            coveringGridFrom: gridFirst,
            through: gridLast,
            selectedDate: CalendarDate(year: 2026, monthIndex: 5, day: 10),
            agendaDays: 0
        )
        XCTAssertEqual(range.first, gridFirst)
        XCTAssertEqual(range.last, gridLast)
    }
}
