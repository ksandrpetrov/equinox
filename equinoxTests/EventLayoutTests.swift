import XCTest
@testable import EquinoxKit

private actor JoinResolutionRecorder {
    private(set) var urls: [URL] = []
    func record(_ url: URL) { urls.append(url) }
}

final class EventLayoutTests: XCTestCase {
    func testDenseDayEventBuilderPreservesTenThousandEvents() async throws {
        let calendar = Calendar.equinoxGregorian(timeZone: try XCTUnwrap(TimeZone(identifier: "UTC")))
        let first = CalendarDate(year: 2026, monthIndex: 9, day: 2).date(in: calendar)
        // Reverse input forces sorting; repeated start times exercise the identity tie-breaker.
        let sources = (0..<10_000).reversed().map { index in
            let start = first.addingTimeInterval(Double(index % 240) * 300)
            return source(identifier: "event-\(index)", start: start, end: start.addingTimeInterval(3600))
        }
        let built = await DayEventBuilder.buildDayEvents(
            from: sources, rangeStart: first, rangeEnd: first.addingTimeInterval(86400), calendar: calendar,
            resolveNativeJoinURL: { _ in XCTFail("Events without links must not query native apps"); return nil }
        )
        XCTAssertEqual(built.count, 1)
        let events = try XCTUnwrap(built[first])
        XCTAssertEqual(events.count, sources.count)
        XCTAssertEqual(Set(events.map(\.id)).count, sources.count)
        XCTAssertTrue(zip(events, events.dropFirst()).allSatisfy { $0.startDate <= $1.startDate })
    }

    func testDayEventBuilderKeepsEveryOccurrenceAndStableOrderAcrossDST() async throws {
        let calendar = Calendar.equinoxGregorian(timeZone: try XCTUnwrap(TimeZone(identifier: "America/Havana")))
        let day = CalendarDate(year: 2026, monthIndex: 2, day: 8)
        let first = day.date(in: calendar)
        let last = day.addingDays(3).date(in: calendar)
        let sources = [
            source(identifier: "series", start: first.addingTimeInterval(7200), end: first.addingTimeInterval(10800)),
            source(identifier: "all-day", start: day.addingDays(-1).date(in: calendar), end: last, isAllDay: true),
            source(identifier: "series", start: first.addingTimeInterval(3600), end: first.addingTimeInterval(5400)),
        ]
        let built = await DayEventBuilder.buildDayEvents(
            from: sources, rangeStart: first, rangeEnd: last, calendar: calendar, resolveNativeJoinURL: { _ in nil }
        )
        let reversed = await DayEventBuilder.buildDayEvents(
            from: sources.reversed(), rangeStart: first, rangeEnd: last, calendar: calendar, resolveNativeJoinURL: { _ in nil }
        )
        XCTAssertEqual(built, reversed, "EventKit result order must not affect presentation")
        XCTAssertEqual(built.count, 3)
        XCTAssertEqual(built.values.flatMap { $0 }.count, 5)
        XCTAssertEqual(Set(built.values.flatMap { $0 }.map(\.id)).count, 5)
        let firstDay = try XCTUnwrap(built[first])
        XCTAssertEqual(firstDay.map(\.eventIdentifier), ["all-day", "series", "series"])
        XCTAssertLessThan(firstDay[1].startDate, firstDay[2].startDate)
        XCTAssertEqual(firstDay[0].startDate, day.addingDays(-1).date(in: calendar))
        XCTAssertEqual(firstDay[0].slotStartDate, first)
        XCTAssertEqual(firstDay[0].slotEndDate, day.addingDays(1).date(in: calendar))
    }

    func testDayEventBuilderResolvesRepeatedJoinURLOnceAndIgnoresClippedEvents() async throws {
        let calendar = Calendar.equinoxGregorian(timeZone: try XCTUnwrap(TimeZone(identifier: "UTC")))
        let first = CalendarDate(year: 2026, monthIndex: 9, day: 2).date(in: calendar)
        let web = try XCTUnwrap(URL(string: "https://zoom.us/j/123?pwd=a%2Bb"))
        let native = try XCTUnwrap(URL(string: "zoommtg://zoom.us/join?confno=123&pwd=a%2Bb"))
        let recorder = JoinResolutionRecorder()
        let notes = "Keep this paragraph.\n\(web.absoluteString)"
        var sources = (0..<3).map { index in
            source(identifier: "event-\(index)", start: first.addingTimeInterval(Double(index) * 3600),
                   end: first.addingTimeInterval(Double(index + 1) * 3600), notes: notes)
        }
        sources.append(source(identifier: "outside", start: first.addingTimeInterval(-7200),
                              end: first, notes: "https://zoom.us/j/999"))
        let built = await DayEventBuilder.buildDayEvents(
            from: sources, rangeStart: first, rangeEnd: first.addingTimeInterval(86400), calendar: calendar,
            resolveNativeJoinURL: { url in await recorder.record(url); return native }
        )
        let resolved = await recorder.urls
        XCTAssertEqual(resolved, [web])
        let events = try XCTUnwrap(built[first])
        XCTAssertEqual(events.count, 3)
        XCTAssertTrue(events.allSatisfy { $0.joinURL == native && $0.notes == notes })
        XCTAssertTrue(events.allSatisfy { $0.calendarIdentifier == "work" && $0.calendarColorRed == 0.2 })
    }

    private func source(
        identifier: String, start: Date, end: Date, isAllDay: Bool = false, notes: String? = nil
    ) -> DayEventSource {
        DayEventSource(
            fields: EventKitEventFields(
                eventIdentifier: identifier, calendarItemIdentifier: identifier, title: "QA \(identifier)",
                location: nil, notes: notes, hasNotes: notes != nil, url: nil,
                startDate: start, endDate: end, isAllDay: isAllDay,
                calendarIdentifier: "work", calendarTitle: "Work", isRecurring: identifier == "series",
                allowsContentModifications: true, participationRawValue: nil
            ),
            calendarColorRed: 0.2, calendarColorGreen: 0.5, calendarColorBlue: 0.8, calendarColorAlpha: 1
        )
    }

    func testAllDayDisplayEndAcceptsInclusiveAndExclusiveEventKitDates() throws {
        for zone in ["UTC", "America/Los_Angeles", "Europe/Moscow"] {
            let calendar = Calendar.equinoxGregorian(timeZone: try XCTUnwrap(TimeZone(identifier: zone)))
            let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)))
            for days in [1, 3] {
                let exclusiveEnd = try XCTUnwrap(calendar.date(byAdding: .day, value: days, to: start))
                let expected = try XCTUnwrap(calendar.date(byAdding: .day, value: days - 1, to: start))
                for end in [exclusiveEnd, exclusiveEnd.addingTimeInterval(-1)] {
                    XCTAssertEqual(inclusiveAllDayEnd(start: start, end: end, calendar: calendar), expected)
                }
            }
            XCTAssertEqual(inclusiveAllDayEnd(start: start, end: start, calendar: calendar), start)
        }
    }

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
