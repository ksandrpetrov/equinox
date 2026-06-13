import XCTest
@testable import equinox

@MainActor
final class AppStateFetchRangeTests: XCTestCase {
    func testFetchRangeExtendsForAgendaDays() {
        let appState = AppState()
        appState.preferences.showEventDays = 3
        let gridFirst = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let gridLast = CalendarDate(year: 2026, monthIndex: 5, day: 30)
        appState.selectedDate = CalendarDate(year: 2026, monthIndex: 5, day: 10)

        let range = appState.fetchRange(coveringGridFrom: gridFirst, through: gridLast)
        XCTAssertEqual(range.first, gridFirst)
        XCTAssertEqual(range.last, CalendarDate(year: 2026, monthIndex: 5, day: 12))
    }

    func testFetchRangePullsEarlierSelectedDate() {
        let appState = AppState()
        appState.preferences.showEventDays = 7
        let gridFirst = CalendarDate(year: 2026, monthIndex: 5, day: 5)
        let gridLast = CalendarDate(year: 2026, monthIndex: 5, day: 30)
        appState.selectedDate = CalendarDate(year: 2026, monthIndex: 5, day: 1)

        let range = appState.fetchRange(coveringGridFrom: gridFirst, through: gridLast)
        XCTAssertEqual(range.first, appState.selectedDate)
    }

    func testFetchRangeNoAgendaDaysReturnsGridOnly() {
        let appState = AppState()
        appState.preferences.showEventDays = 0
        let gridFirst = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        let gridLast = CalendarDate(year: 2026, monthIndex: 5, day: 30)

        let range = appState.fetchRange(coveringGridFrom: gridFirst, through: gridLast)
        XCTAssertEqual(range.first, gridFirst)
        XCTAssertEqual(range.last, gridLast)
    }
}
