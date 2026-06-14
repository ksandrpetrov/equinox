import XCTest
@testable import equinox

final class MeetingIndicatorTests: XCTestCase {
    func testShowsIndicatorForJoinURLWithinWindow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let event = sampleEvent(
            start: now.addingTimeInterval(10 * 60),
            end: now.addingTimeInterval(40 * 60),
            joinURL: URL(string: "https://zoom.us/j/123")
        )
        let eventsByDate = [CalendarDate(date: now, calendar: calendar): [event]]

        XCTAssertTrue(MeetingIndicator.shouldShow(
            eventsByDate: eventsByDate,
            now: now,
            calendar: calendar
        ))
    }

    func testHidesIndicatorWithoutJoinURL() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let event = sampleEvent(
            start: now.addingTimeInterval(10 * 60),
            end: now.addingTimeInterval(40 * 60),
            joinURL: nil
        )
        let eventsByDate = [CalendarDate(date: now, calendar: calendar): [event]]

        XCTAssertFalse(MeetingIndicator.shouldShow(
            eventsByDate: eventsByDate,
            now: now,
            calendar: calendar
        ))
    }

    private func sampleEvent(start: Date, end: Date, joinURL: URL?) -> DayEvent {
        DayEvent(
            id: "test",
            eventIdentifier: "evt-1",
            calendarItemIdentifier: "item-1",
            title: "Standup",
            location: nil,
            notes: nil,
            url: nil,
            startDate: start,
            endDate: end,
            isEventAllDay: false,
            isFirstDayOfSpan: true,
            isLastDayOfSpan: true,
            isSlotAllDay: false,
            joinURL: joinURL,
            calendarIdentifier: "cal-1",
            calendarTitle: "Work",
            calendarColorRed: 1,
            calendarColorGreen: 0,
            calendarColorBlue: 0,
            calendarColorAlpha: 1,
            allowsContentModifications: true,
            hasAttendees: false,
            participationStatus: nil
        )
    }
}
