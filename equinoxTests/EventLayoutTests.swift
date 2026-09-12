import XCTest
@testable import EquinoxKit

final class EventLayoutTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testSlotsPartitionClippedEventsAcrossTimeZoneTransitions() throws {
        let transitions = [
            ("America/Los_Angeles", 2026, 3, 8),
            ("America/Los_Angeles", 2026, 11, 1),
            ("Australia/Lord_Howe", 2026, 4, 5),
            ("Australia/Lord_Howe", 2026, 10, 4),
            ("Pacific/Apia", 2011, 12, 29),
            ("Europe/Moscow", 2026, 9, 12),
        ]
        for (zone, year, month, day) in transitions {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try XCTUnwrap(TimeZone(identifier: zone))
            let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day)))
            let rangeStart = anchor.addingTimeInterval(-12 * 3600)
            let rangeEnd = anchor.addingTimeInterval(60 * 3600)
            for offset in [-36, -12, 0, 1, 12, 23, 24, 48, 60, 72] {
                for duration in [0, 1, 12, 24, 25, 49, 96] {
                    let start = anchor.addingTimeInterval(Double(offset * 3600))
                    let end = start.addingTimeInterval(Double(duration * 3600))
                    let slots = layoutEventDaySlots(
                        event: EventLayoutInput(startDate: start, endDate: end, isAllDay: false),
                        rangeStart: rangeStart, rangeEnd: rangeEnd, calendar: calendar
                    )
                    let expectedStart = max(start, rangeStart)
                    let expectedEnd = min(end, rangeEnd)
                    if expectedStart >= expectedEnd {
                        XCTAssertTrue(slots.isEmpty, "\(zone): \(offset), \(duration)")
                        continue
                    }
                    XCTAssertEqual(slots.first?.startDate, expectedStart)
                    XCTAssertEqual(slots.last?.endDate, expectedEnd)
                    XCTAssertEqual(Set(slots.map(\.dayStart)).count, slots.count)
                    XCTAssertEqual(slots.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) },
                                   expectedEnd.timeIntervalSince(expectedStart), accuracy: 0.001)
                    for (index, slot) in slots.enumerated() {
                        XCTAssertLessThan(slot.startDate, slot.endDate)
                        XCTAssertEqual(calendar.startOfDay(for: slot.startDate), slot.dayStart)
                        if index > 0 { XCTAssertEqual(slots[index - 1].endDate, slot.startDate) }
                    }
                }
            }
        }
    }

    func testSingleDayEventProducesOneSlot() {
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 10
        components.hour = 10
        let start = calendar.date(from: components)!
        let end = calendar.date(byAdding: .hour, value: 1, to: start)!

        let slots = layoutEventDaySlots(
            event: EventLayoutInput(startDate: start, endDate: end, isAllDay: false),
            rangeStart: calendar.startOfDay(for: start),
            rangeEnd: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start))!,
            calendar: calendar
        )

        XCTAssertEqual(slots.count, 1)
        XCTAssertFalse(slots[0].displaysAsAllDay)
        XCTAssertEqual(slots[0].startDate, start)
        XCTAssertEqual(slots[0].endDate, end)
    }

    func testAllDayEventsSortBeforeTimedEvents() {
        let allDay = sortKey(isEventAllDay: true, isSlotAllDay: true, calendarTitle: "B", startDate: .distantPast)
        let timed = sortKey(isEventAllDay: false, isSlotAllDay: false, calendarTitle: "A", startDate: .distantPast)
        XCTAssertTrue(precedesInDisplayOrder(allDay, timed))
        XCTAssertFalse(precedesInDisplayOrder(timed, allDay))
    }

    func testTimedEventsSortByStartDate() {
        let earlier = sortKey(isEventAllDay: false, isSlotAllDay: false, calendarTitle: "A", startDate: Date(timeIntervalSince1970: 100))
        let later = sortKey(isEventAllDay: false, isSlotAllDay: false, calendarTitle: "A", startDate: Date(timeIntervalSince1970: 200))
        XCTAssertTrue(precedesInDisplayOrder(earlier, later))
    }

    func testSimultaneousTimedEventsSortByCalendarTitle() {
        let start = Date(timeIntervalSince1970: 100)
        let alpha = sortKey(isEventAllDay: false, isSlotAllDay: false, calendarTitle: "Alpha", startDate: start)
        let beta = sortKey(isEventAllDay: false, isSlotAllDay: false, calendarTitle: "Beta", startDate: start)
        XCTAssertTrue(precedesInDisplayOrder(alpha, beta))
        XCTAssertFalse(precedesInDisplayOrder(beta, alpha))
    }

    func testSimultaneousEventsInSameCalendarSortByTitleThenIdentifier() {
        let start = Date(timeIntervalSince1970: 100)
        let alpha = sortKey(calendarTitle: "Work", startDate: start, title: "Alpha", id: "z")
        let beta = sortKey(calendarTitle: "Work", startDate: start, title: "Beta", id: "a")
        let firstCopy = sortKey(calendarTitle: "Work", startDate: start, title: "Alpha", id: "a")

        XCTAssertTrue(precedesInDisplayOrder(alpha, beta))
        XCTAssertTrue(precedesInDisplayOrder(firstCopy, alpha))
        XCTAssertFalse(precedesInDisplayOrder(alpha, firstCopy))
    }

    func testMultiDayEventProducesMultipleSlots() {
        var startComponents = DateComponents()
        startComponents.year = 2024
        startComponents.month = 6
        startComponents.day = 10
        startComponents.hour = 22
        let start = calendar.date(from: startComponents)!

        var endComponents = DateComponents()
        endComponents.year = 2024
        endComponents.month = 6
        endComponents.day = 12
        endComponents.hour = 8
        let end = calendar.date(from: endComponents)!

        let rangeStart = calendar.startOfDay(for: start)
        let rangeEnd = calendar.date(byAdding: .day, value: 5, to: rangeStart)!

        let slots = layoutEventDaySlots(
            event: EventLayoutInput(startDate: start, endDate: end, isAllDay: false),
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            calendar: calendar
        )

        let june11 = calendar.date(byAdding: .day, value: 1, to: rangeStart)!
        let june12 = calendar.date(byAdding: .day, value: 2, to: rangeStart)!

        XCTAssertEqual(slots.count, 3)
        XCTAssertEqual(slots.map(\.displaysAsAllDay), [false, true, false])
        XCTAssertEqual(slots.map(\.startDate), [start, june11, june12])
        XCTAssertEqual(slots.map(\.endDate), [june11, june12, end])
    }

    func testTimedEventCoveringExactCivilDayDisplaysAsAllDaySlot() {
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 10
        let start = calendar.date(from: components)!
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let slots = layoutEventDaySlots(
            event: EventLayoutInput(startDate: start, endDate: end, isAllDay: false),
            rangeStart: start,
            rangeEnd: end,
            calendar: calendar
        )

        XCTAssertEqual(slots.count, 1)
        XCTAssertTrue(slots[0].displaysAsAllDay)
        XCTAssertEqual(slots[0].startDate, start)
        XCTAssertEqual(slots[0].endDate, end)
    }

    func testTimedEventCoveringDSTCivilDayDisplaysAsAllDaySlot() {
        var dstCalendar = Calendar(identifier: .gregorian)
        dstCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let start = dstCalendar.date(from: DateComponents(year: 2024, month: 3, day: 10))!
        let end = dstCalendar.date(byAdding: .day, value: 1, to: start)!

        let slots = layoutEventDaySlots(
            event: EventLayoutInput(startDate: start, endDate: end, isAllDay: false),
            rangeStart: start,
            rangeEnd: end,
            calendar: dstCalendar
        )

        XCTAssertEqual(end.timeIntervalSince(start), 23 * 60 * 60)
        XCTAssertEqual(slots.count, 1)
        XCTAssertTrue(slots[0].displaysAsAllDay)
        XCTAssertEqual(slots[0].startDate, start)
        XCTAssertEqual(slots[0].endDate, end)
    }

    private func sortKey(
        isEventAllDay: Bool = false,
        isSlotAllDay: Bool = false,
        calendarTitle: String,
        startDate: Date,
        title: String = "Event",
        id: String = "id"
    ) -> EventSortKey {
        EventSortKey(
            isEventAllDay: isEventAllDay,
            isSlotAllDay: isSlotAllDay,
            calendarTitle: calendarTitle,
            startDate: startDate,
            title: title,
            stableIdentifier: id
        )
    }
}
