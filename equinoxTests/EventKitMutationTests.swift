import EventKit
import XCTest
@testable import EquinoxKit

@MainActor
final class EventKitMutationTests: XCTestCase {
    func testDraftMapsToUnsavedEventIncludingRecurrenceAndAlarm() throws {
        // Allocate objects only: no access request, fetch, save, or remove.
        let store = EKEventStore()
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "Test calendar"
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        for (frequency, expected, interval): (RecurrenceFrequency, EKRecurrenceFrequency, Int) in [
            (.daily, .daily, 1), (.weekly, .weekly, 1), (.biweekly, .weekly, 2),
            (.monthly, .monthly, 1), (.yearly, .yearly, 1)
        ] {
            let event = EKEvent(eventStore: store)
            let repeatEnd = start.addingTimeInterval(86400 * 365)
            let draft = NewEventDraft(title: "Meeting", location: "Room", url: URL(string: "https://example.com"),
                                      notes: "Notes", isAllDay: false, startDate: start, endDate: start.addingTimeInterval(3600),
                                      calendarIdentifier: calendar.calendarIdentifier,
                                      recurrence: RecurrenceDraft(frequency: frequency, endDate: repeatEnd), alertOffset: -900)
            EventKitMutation.applyCreate(from: draft, to: event, calendar: calendar)
            XCTAssertEqual(event.title, draft.title)
            XCTAssertEqual(event.location, draft.location)
            XCTAssertEqual(event.url, draft.url)
            XCTAssertEqual(event.notes, draft.notes)
            XCTAssertEqual(event.startDate, draft.startDate)
            XCTAssertEqual(event.endDate, draft.endDate)
            XCTAssertEqual(event.calendar, calendar)
            XCTAssertFalse(event.isAllDay)
            XCTAssertEqual(event.timeZone, .current)
            let rule = try XCTUnwrap(event.recurrenceRules?.first)
            XCTAssertEqual(rule.frequency, expected)
            XCTAssertEqual(rule.interval, interval)
            XCTAssertEqual(rule.recurrenceEnd?.endDate, repeatEnd)
            XCTAssertEqual(event.alarms?.map(\.relativeOffset), [-900])
        }
    }

    func testAllDayDraftPreservesExclusiveEndAndOmitsOptionalFields() {
        let store = EKEventStore()
        let calendar = EKCalendar(for: .event, eventStore: store)
        let event = EKEvent(eventStore: store)
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 2, to: start)!
        let draft = NewEventDraft(title: "Two days", location: "", url: nil, notes: nil, isAllDay: true,
                                  startDate: start, endDate: end, calendarIdentifier: calendar.calendarIdentifier,
                                  recurrence: nil, alertOffset: nil)
        EventKitMutation.applyCreate(from: draft, to: event, calendar: calendar)
        XCTAssertTrue(event.isAllDay)
        XCTAssertEqual(event.startDate, start)
        let slots = layoutEventDaySlots(
            event: EventLayoutInput(startDate: event.startDate, endDate: event.endDate, isAllDay: true),
            rangeStart: start, rangeEnd: end.addingTimeInterval(86400), calendar: .current
        )
        XCTAssertEqual(slots.count, 2, "EventKit must not include the exclusive end date as a third day")
        XCTAssertEqual(slots.last?.dayStart, Calendar.current.date(byAdding: .day, value: 1, to: start))
        XCTAssertNil(event.timeZone)
        XCTAssertNil(event.location)
        XCTAssertNil(event.url)
        XCTAssertNil(event.notes)
        XCTAssertTrue(event.recurrenceRules?.isEmpty ?? true)
        XCTAssertTrue(event.alarms?.isEmpty ?? true)
    }
}
