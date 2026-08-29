import XCTest
@testable import equinox

final class AgendaSectionsTests: XCTestCase {
    private func makeEvent(on date: CalendarDate, eventIdentifier: String? = "evt") -> DayEvent {
        DayEvent(
            id: "e-\(date.julian)",
            eventIdentifier: eventIdentifier,
            calendarItemIdentifier: "ci-1",
            title: "Event",
            location: nil,
            notes: nil,
            url: nil,
            startDate: date.date(in: .autoupdatingCurrent),
            endDate: date.date(in: .autoupdatingCurrent),
            isEventAllDay: false,
            isSlotAllDay: false,
            joinURL: nil,
            calendarIdentifier: "cal-1",
            calendarTitle: "Work",
            calendarColorRed: 1,
            calendarColorGreen: 0,
            calendarColorBlue: 0,
            calendarColorAlpha: 1,
            allowsContentModifications: true,
            participationStatus: nil
        )
    }

    func testDeletionRequiresPersistedEventIdentifier() {
        let date = CalendarDate(year: 2026, monthIndex: 5, day: 14)

        XCTAssertTrue(makeEvent(on: date).allowsDeletion)
        XCTAssertFalse(makeEvent(on: date, eventIdentifier: nil).allowsDeletion)
    }

    func testOccurrenceIdentityUsesEventIDAndStableFallback() {
        let date = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        XCTAssertTrue(
            makeEvent(on: date, eventIdentifier: "event-a")
                .representsSameOccurrence(as: makeEvent(on: date, eventIdentifier: "event-a"))
        )
        XCTAssertFalse(
            makeEvent(on: date, eventIdentifier: "event-a")
                .representsSameOccurrence(as: makeEvent(on: date, eventIdentifier: "event-b"))
        )
        XCTAssertFalse(
            makeEvent(on: date, eventIdentifier: "event-a")
                .representsSameOccurrence(as: makeEvent(on: date.addingDays(1), eventIdentifier: "event-a"))
        )
        XCTAssertTrue(
            makeEvent(on: date, eventIdentifier: nil)
                .representsSameOccurrence(as: makeEvent(on: date, eventIdentifier: nil))
        )
        XCTAssertFalse(
            makeEvent(on: date, eventIdentifier: nil)
                .representsSameOccurrence(as: makeEvent(on: date.addingDays(1), eventIdentifier: nil))
        )
    }

    func testIncludesOnlyDaysWithEventsWhenEmptyDaysDisabled() {
        let start = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let day2 = start.addingDays(1)
        let sections = AgendaSections.sections(
            from: start,
            days: 3,
            showEmptyDays: false,
            eventsFor: { date in
                date == day2 ? [makeEvent(on: date)] : []
            }
        )
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.0, day2)
    }

    func testIncludesEmptyDaysWhenEnabled() {
        let start = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let sections = AgendaSections.sections(
            from: start,
            days: 2,
            showEmptyDays: true,
            eventsFor: { _ in [] }
        )
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections.map(\.0), [start, start.addingDays(1)])
    }

    func testRangeIncludesPinnedDateWhenEmptyDaysDisabled() {
        let first = CalendarDate(year: 2026, monthIndex: 5, day: 10)
        let selected = first.addingDays(2)
        let last = first.addingDays(4)
        let sections = AgendaSections.sections(
            from: first,
            through: last,
            pinnedDate: selected,
            showEmptyDays: false,
            eventsFor: { _ in [] }
        )
        XCTAssertEqual(sections.map(\.0), [selected])
    }

    func testRangeCoversPastAndFutureDays() {
        let selected = CalendarDate(year: 2026, monthIndex: 5, day: 14)
        let sections = AgendaSections.sections(
            from: selected.addingDays(-2),
            through: selected.addingDays(2),
            pinnedDate: selected,
            showEmptyDays: true,
            eventsFor: { _ in [] }
        )
        XCTAssertEqual(sections.count, 5)
        XCTAssertEqual(sections.map(\.0).first, selected.addingDays(-2))
        XCTAssertEqual(sections.map(\.0).last, selected.addingDays(2))
    }
}
