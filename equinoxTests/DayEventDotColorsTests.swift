import AppKit
import XCTest
@testable import equinox

final class DayEventDotColorsTests: XCTestCase {
    private func makeEvent(calendarID: String, red: CGFloat) -> DayEvent {
        DayEvent(
            id: "\(calendarID)-1",
            eventIdentifier: "e-\(calendarID)",
            calendarItemIdentifier: "ci-\(calendarID)",
            title: "Event",
            location: nil,
            notes: nil,
            url: nil,
            startDate: Date(),
            endDate: Date(),
            isEventAllDay: false,
            isFirstDayOfSpan: true,
            isLastDayOfSpan: true,
            isSlotAllDay: false,
            joinURL: nil,
            calendarIdentifier: calendarID,
            calendarTitle: calendarID,
            calendarColorRed: red,
            calendarColorGreen: 0,
            calendarColorBlue: 0,
            calendarColorAlpha: 1,
            allowsContentModifications: true,
            hasAttendees: false,
            participationStatus: nil
        )
    }

    func testEmptyEventsReturnsNil() {
        XCTAssertNil(DayEvent.makeDotColors(for: []))
    }

    func testDeduplicatesCalendars() {
        let events = [
            makeEvent(calendarID: "a", red: 1),
            makeEvent(calendarID: "a", red: 1),
            makeEvent(calendarID: "b", red: 0.5),
        ]
        let colors = DayEvent.makeDotColors(for: events)
        XCTAssertEqual(colors?.count, 2)
    }

    func testCapsAtThreeColors() {
        let events = (0..<5).map { makeEvent(calendarID: "cal-\($0)", red: CGFloat($0) / 5) }
        XCTAssertEqual(DayEvent.makeDotColors(for: events)?.count, 3)
    }
}
