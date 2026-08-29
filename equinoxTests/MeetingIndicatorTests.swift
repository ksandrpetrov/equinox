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

    func testHidesIndicatorForAllDayEvents() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let event = sampleEvent(
            start: now.addingTimeInterval(10 * 60),
            end: now.addingTimeInterval(40 * 60),
            joinURL: URL(string: "https://zoom.us/j/123"),
            isEventAllDay: true
        )
        let eventsByDate = [CalendarDate(date: now, calendar: calendar): [event]]

        XCTAssertFalse(MeetingIndicator.shouldShow(
            eventsByDate: eventsByDate,
            now: now,
            calendar: calendar
        ))
    }

    func testHidesIndicatorForDeclinedMeeting() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let event = sampleEvent(
            start: now.addingTimeInterval(10 * 60),
            end: now.addingTimeInterval(40 * 60),
            joinURL: URL(string: "https://zoom.us/j/123"),
            participationStatus: .declined
        )

        XCTAssertFalse(MeetingIndicator.shouldShow(
            eventsByDate: [CalendarDate(date: now, calendar: calendar): [event]],
            now: now,
            calendar: calendar
        ))
    }

    func testHidesIndicatorWhenMeetingStartsAfterLookaheadWindow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let event = sampleEvent(
            start: now.addingTimeInterval(45 * 60),
            end: now.addingTimeInterval(75 * 60),
            joinURL: URL(string: "https://zoom.us/j/123")
        )
        let eventsByDate = [CalendarDate(date: now, calendar: calendar): [event]]

        XCTAssertFalse(MeetingIndicator.shouldShow(
            eventsByDate: eventsByDate,
            now: now,
            calendar: calendar,
            lookaheadMinutes: 30
        ))
    }

    func testHidesIndicatorWhenMeetingAlreadyEnded() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let event = sampleEvent(
            start: now.addingTimeInterval(-60 * 60),
            end: now.addingTimeInterval(-5 * 60),
            joinURL: URL(string: "https://zoom.us/j/123")
        )
        let eventsByDate = [CalendarDate(date: now, calendar: calendar): [event]]

        XCTAssertFalse(MeetingIndicator.shouldShow(
            eventsByDate: eventsByDate,
            now: now,
            calendar: calendar
        ))
    }

    func testShowsIndicatorForInProgressMeeting() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let event = sampleEvent(
            start: now.addingTimeInterval(-10 * 60),
            end: now.addingTimeInterval(20 * 60),
            joinURL: URL(string: "https://zoom.us/j/123")
        )
        let eventsByDate = [CalendarDate(date: now, calendar: calendar): [event]]

        XCTAssertTrue(MeetingIndicator.shouldShow(
            eventsByDate: eventsByDate,
            now: now,
            calendar: calendar
        ))
    }

    func testJoinUrgencyUsesSameEligibilityAsIndicator() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let urgent = sampleEvent(
            start: now.addingTimeInterval(30 * 60),
            end: now.addingTimeInterval(60 * 60),
            joinURL: URL(string: "https://zoom.us/j/123")
        )
        let distant = sampleEvent(
            start: now.addingTimeInterval(31 * 60),
            end: now.addingTimeInterval(61 * 60),
            joinURL: URL(string: "https://zoom.us/j/123")
        )

        XCTAssertTrue(MeetingIndicator.isJoinActionUrgent(urgent, now: now, calendar: calendar))
        XCTAssertFalse(MeetingIndicator.isJoinActionUrgent(distant, now: now, calendar: calendar))
    }

    private func sampleEvent(
        start: Date,
        end: Date,
        joinURL: URL?,
        isEventAllDay: Bool = false,
        participationStatus: EventParticipationStatus? = nil
    ) -> DayEvent {
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
            isEventAllDay: isEventAllDay,
            isSlotAllDay: false,
            joinURL: joinURL,
            calendarIdentifier: "cal-1",
            calendarTitle: "Work",
            calendarColorRed: 1,
            calendarColorGreen: 0,
            calendarColorBlue: 0,
            calendarColorAlpha: 1,
            allowsContentModifications: true,
            participationStatus: participationStatus
        )
    }
}
