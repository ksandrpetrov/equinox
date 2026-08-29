import XCTest
@testable import equinox

final class EventLayoutTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

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

        XCTAssertGreaterThanOrEqual(slots.count, 2)
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
