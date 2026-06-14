import XCTest
@testable import equinox

final class AgendaDisplayRangeTests: XCTestCase {
    func testSevenDaysCenteredOnAnchor() {
        let anchor = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let range = AgendaDisplayRange.range(anchor: anchor, showEventDays: 7)
        XCTAssertEqual(range.first, CalendarDate(year: 2026, monthIndex: 5, day: 11))
        XCTAssertEqual(range.last, CalendarDate(year: 2026, monthIndex: 5, day: 17))
    }

    func testSingleDayRange() {
        let anchor = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let range = AgendaDisplayRange.range(anchor: anchor, showEventDays: 1)
        XCTAssertEqual(range.first, anchor)
        XCTAssertEqual(range.last, anchor)
    }

    func testTwoDaysRangeIncludesTodayAndTomorrow() {
        let anchor = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let range = AgendaDisplayRange.range(anchor: anchor, showEventDays: 2)
        XCTAssertEqual(range.first, anchor)
        XCTAssertEqual(range.last, anchor.addingDays(1))
    }
}
