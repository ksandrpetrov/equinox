import SwiftUI
import XCTest
@testable import EquinoxKit

final class DayEventUniqueCalendarsTests: XCTestCase {
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
            slotStartDate: Date(),
            slotEndDate: Date(),
            isEventAllDay: false,
            isSlotAllDay: false,
            joinURL: nil,
            calendarIdentifier: calendarID,
            calendarTitle: calendarID,
            calendarColorRed: red,
            calendarColorGreen: 0,
            calendarColorBlue: 0,
            calendarColorAlpha: 1,
            isRecurring: false,
            allowsContentModifications: true,
            participationStatus: nil
        )
    }

    func testEmptyEventsReturnsNil() {
        XCTAssertNil(DayEvent.makeSwiftUIDotColors(for: []))
    }

    func testDotColorsPreserveFirstCalendarOrderAndComponents() {
        let events = [
            makeEvent(calendarID: "a", red: 0.2),
            makeEvent(calendarID: "a", red: 0.9),
            makeEvent(calendarID: "b", red: 0.4),
            makeEvent(calendarID: "c", red: 0.6),
            makeEvent(calendarID: "d", red: 0.8),
        ]
        XCTAssertEqual(DayEvent.makeSwiftUIDotColors(for: events), [
            Color(red: 0.2, green: 0, blue: 0, opacity: 1),
            Color(red: 0.4, green: 0, blue: 0, opacity: 1),
            Color(red: 0.6, green: 0, blue: 0, opacity: 1),
        ])
    }

    func testMakeUniqueCalendarEventsReturnsNilForEmpty() {
        XCTAssertNil(DayEvent.makeUniqueCalendarEvents(for: []))
    }

    func testMakeUniqueCalendarEventsDeduplicatesCalendars() {
        let events = [
            makeEvent(calendarID: "a", red: 1),
            makeEvent(calendarID: "a", red: 1),
            makeEvent(calendarID: "b", red: 0.5),
        ]
        let unique = DayEvent.makeUniqueCalendarEvents(for: events)
        XCTAssertEqual(unique?.map(\.calendarIdentifier), ["a", "b"])
    }

    func testMakeUniqueCalendarEventsCapsAtThree() {
        let events = (0..<5).map { makeEvent(calendarID: "cal-\($0)", red: CGFloat($0) / 5) }
        XCTAssertEqual(DayEvent.makeUniqueCalendarEvents(for: events)?.count, 3)
    }
}
