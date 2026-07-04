import XCTest
@testable import equinox

final class AgendaFocusTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testFocusesOngoingMeeting() {
        let past = makeEvent(id: "past", start: now.addingTimeInterval(-2 * 3600), end: now.addingTimeInterval(-3600))
        let ongoing = makeEvent(id: "ongoing", start: now.addingTimeInterval(-900), end: now.addingTimeInterval(900))
        let upcoming = makeEvent(id: "upcoming", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200))

        XCTAssertEqual(
            AgendaFocus.focusEventID(in: [upcoming, past, ongoing], now: now),
            "ongoing"
        )
    }

    func testFocusesNextUpcomingWhenNoneOngoing() {
        let past = makeEvent(id: "past", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600))
        let next = makeEvent(id: "next", start: now.addingTimeInterval(1800), end: now.addingTimeInterval(3600))
        let later = makeEvent(id: "later", start: now.addingTimeInterval(7200), end: now.addingTimeInterval(10_800))

        XCTAssertEqual(
            AgendaFocus.focusEventID(in: [later, past, next], now: now),
            "next"
        )
    }

    func testReturnsNilWhenAllTimedEventsArePast() {
        let past = makeEvent(id: "past", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600))

        XCTAssertNil(AgendaFocus.focusEventID(in: [past], now: now))
    }

    func testIgnoresAllDayEvents() {
        let allDay = makeEvent(
            id: "all-day",
            start: now.addingTimeInterval(-3600),
            end: now.addingTimeInterval(3600),
            isEventAllDay: true
        )
        let upcoming = makeEvent(id: "upcoming", start: now.addingTimeInterval(1800), end: now.addingTimeInterval(3600))

        XCTAssertEqual(AgendaFocus.focusEventID(in: [allDay], now: now), nil)
        XCTAssertEqual(AgendaFocus.focusEventID(in: [allDay, upcoming], now: now), "upcoming")
    }

    func testPrefersEarlierOngoingWhenOverlapping() {
        let first = makeEvent(id: "first", start: now.addingTimeInterval(-1800), end: now.addingTimeInterval(1800))
        let second = makeEvent(id: "second", start: now.addingTimeInterval(-900), end: now.addingTimeInterval(900))

        XCTAssertEqual(
            AgendaFocus.focusEventID(in: [second, first], now: now),
            "first"
        )
    }

    // MARK: - Cross-day focus

    private let today = CalendarDate(year: 2023, monthIndex: 10, day: 14)
    private let day: TimeInterval = 86_400

    private func crossDayFocus(_ eventsByDate: [CalendarDate: [DayEvent]]) -> String? {
        AgendaFocus.focusEventID(
            from: today,
            through: today.addingDays(45),
            eventsFor: { eventsByDate[$0] ?? [] },
            now: now
        )
    }

    func testCrossDayFocusesTomorrowWhenTodayAllPast() {
        let eventsByDate: [CalendarDate: [DayEvent]] = [
            today: [makeEvent(id: "past-today", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600))],
            today.addingDays(1): [makeEvent(id: "tomorrow", start: now.addingTimeInterval(day), end: now.addingTimeInterval(day + 3600))]
        ]

        XCTAssertEqual(crossDayFocus(eventsByDate), "tomorrow")
    }

    func testCrossDaySkipsEmptyDaysToNextEvent() {
        let eventsByDate: [CalendarDate: [DayEvent]] = [
            today.addingDays(2): [makeEvent(id: "in-two-days", start: now.addingTimeInterval(2 * day), end: now.addingTimeInterval(2 * day + 3600))]
        ]

        XCTAssertEqual(crossDayFocus(eventsByDate), "in-two-days")
    }

    func testCrossDayPrefersTodayOngoingOverTomorrow() {
        let eventsByDate: [CalendarDate: [DayEvent]] = [
            today: [makeEvent(id: "ongoing-today", start: now.addingTimeInterval(-900), end: now.addingTimeInterval(900))],
            today.addingDays(1): [makeEvent(id: "tomorrow", start: now.addingTimeInterval(day), end: now.addingTimeInterval(day + 3600))]
        ]

        XCTAssertEqual(crossDayFocus(eventsByDate), "ongoing-today")
    }

    func testCrossDayReturnsNilWhenAllTimedEventsArePast() {
        let eventsByDate: [CalendarDate: [DayEvent]] = [
            today: [makeEvent(id: "past", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600))]
        ]

        XCTAssertNil(crossDayFocus(eventsByDate))
    }

    func testCrossDaySkipsAllDayOnlyTodayToTimedTomorrow() {
        let eventsByDate: [CalendarDate: [DayEvent]] = [
            today: [makeEvent(id: "all-day", start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(3600), isEventAllDay: true)],
            today.addingDays(1): [makeEvent(id: "tomorrow", start: now.addingTimeInterval(day), end: now.addingTimeInterval(day + 3600))]
        ]

        XCTAssertEqual(crossDayFocus(eventsByDate), "tomorrow")
    }

    private func makeEvent(
        id: String,
        start: Date,
        end: Date,
        isEventAllDay: Bool = false
    ) -> DayEvent {
        DayEvent(
            id: id,
            eventIdentifier: "evt-\(id)",
            calendarItemIdentifier: "item-\(id)",
            title: "Meeting \(id)",
            location: nil,
            notes: nil,
            url: nil,
            startDate: start,
            endDate: end,
            isEventAllDay: isEventAllDay,
            isFirstDayOfSpan: true,
            isLastDayOfSpan: true,
            isSlotAllDay: false,
            joinURL: nil,
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

    func testProgrammaticScrollSettleDelayIsPositive() {
        XCTAssertGreaterThan(AgendaFocus.programmaticScrollSettleDelay, 0)
    }
}
