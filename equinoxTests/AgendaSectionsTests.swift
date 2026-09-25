import XCTest
@testable import EquinoxKit

final class AgendaSectionsTests: XCTestCase {
    func testTopVisibleDateFollowsPinnedHeaderUntilNextDayReachesTop() {
        let day = CalendarDate(year: 2026, monthIndex: 10, day: 27)
        let next = day.addingDays(1)
        XCTAssertEqual(AgendaSections.topVisibleDate(headerOffsets: [day: 0, next: 180]), day)
        XCTAssertEqual(AgendaSections.topVisibleDate(headerOffsets: [day: -12, next: 20]), day)
        XCTAssertEqual(AgendaSections.topVisibleDate(headerOffsets: [day: -32, next: 0]), next)
        XCTAssertEqual(AgendaSections.topVisibleDate(headerOffsets: [day: 0, next: 0]), next)
        XCTAssertEqual(AgendaSections.topVisibleDate(headerOffsets: [day: 0, next: 20]), day)
    }

    func testTopVisibleDateHandlesUnpinnedHeadersAndOverscroll() {
        let day = CalendarDate(year: 2026, monthIndex: 11, day: 31)
        let next = day.addingDays(1)
        XCTAssertEqual(AgendaSections.topVisibleDate(headerOffsets: [day: -250, next: -40]), next)
        XCTAssertEqual(AgendaSections.topVisibleDate(headerOffsets: [day: 15, next: 90]), day)
        XCTAssertNil(AgendaSections.topVisibleDate(headerOffsets: [:]))
        XCTAssertNil(AgendaSections.topVisibleDate(headerOffsets: [day: .nan, next: .infinity]))
    }

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
            slotStartDate: date.date(in: .autoupdatingCurrent),
            slotEndDate: date.date(in: .autoupdatingCurrent),
            isEventAllDay: false,
            isSlotAllDay: false,
            joinURL: nil,
            calendarIdentifier: "cal-1",
            calendarTitle: "Work",
            calendarColorRed: 1,
            calendarColorGreen: 0,
            calendarColorBlue: 0,
            calendarColorAlpha: 1,
            isRecurring: false,
            allowsContentModifications: true,
            participationStatus: nil
        )
    }

    func testDeletionRequiresPersistedEventIdentifier() {
        let date = CalendarDate(year: 2026, monthIndex: 5, day: 14)

        XCTAssertTrue(makeEvent(on: date).allowsDeletion)
        XCTAssertFalse(makeEvent(on: date, eventIdentifier: nil).allowsDeletion)
    }

    func testDayEventMappingPreservesRecurrenceFlag() {
        let startDate = Date(timeIntervalSince1970: 1_800_000_000)
        let fields = EventKitEventFields(
            eventIdentifier: "event-1",
            calendarItemIdentifier: "item-1",
            title: "Weekly sync",
            location: nil,
            notes: nil,
            hasNotes: false,
            url: nil,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(3_600),
            isAllDay: false,
            calendarIdentifier: "calendar-1",
            calendarTitle: "Work",
            isRecurring: true,
            allowsContentModifications: true,
            participationRawValue: nil
        )

        let event = DayEventMapping.dayEvent(
            from: fields,
            calendarColorComponents: (red: 1, green: 0, blue: 0, alpha: 1),
            slot: EventDaySlot(
                dayStart: startDate,
                startDate: startDate,
                endDate: startDate.addingTimeInterval(3_600),
                displaysAsAllDay: false
            ),
            joinURL: nil,
            dayKey: startDate
        )

        XCTAssertTrue(event.isRecurring)
        XCTAssertEqual(event.slotStartDate, startDate)
        XCTAssertEqual(event.slotEndDate, startDate.addingTimeInterval(3_600))
    }

    func testDayEventBuilderSortsContinuationsByVisibleSlotStart() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let targetDay = calendar.date(from: DateComponents(year: 2026, month: 6, day: 11))!
        let targetEnd = calendar.date(byAdding: .day, value: 1, to: targetDay)!
        let alphaStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 23))!
        let betaStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 22))!

        let eventsByDate = await DayEventBuilder.buildDayEvents(
            from: [
                makeSource(
                    identifier: "beta",
                    title: "Beta",
                    startDate: betaStart,
                    endDate: calendar.date(byAdding: .hour, value: 10, to: targetDay)!
                ),
                makeSource(
                    identifier: "alpha",
                    title: "Alpha",
                    startDate: alphaStart,
                    endDate: calendar.date(byAdding: .hour, value: 9, to: targetDay)!
                )
            ],
            rangeStart: targetDay,
            rangeEnd: targetEnd,
            calendar: calendar,
            resolveNativeJoinURL: { _ in nil }
        )

        let events = try XCTUnwrap(eventsByDate[targetDay])
        XCTAssertEqual(events.map(\.title), ["Alpha", "Beta"])
        XCTAssertEqual(events.map(\.slotStartDate), [targetDay, targetDay])
        XCTAssertEqual(events.map(\.displaysAsAllDay), [false, false])
    }

    func testDetachedOccurrenceIsStillClassifiedAsRecurring() {
        XCTAssertTrue(
            EventKitEventFields.isRecurring(
                hasRecurrenceRules: false,
                isDetached: true
            )
        )
        XCTAssertFalse(
            EventKitEventFields.isRecurring(
                hasRecurrenceRules: false,
                isDetached: false
            )
        )
    }

    func testDeleteConfirmationTitleMatchesEventRecurrence() {
        XCTAssertEqual(
            EventDeletionConfirmation.title(isRecurring: false),
            String(localized: "Delete event?", bundle: .equinox, comment: "Delete event confirmation title")
        )
        XCTAssertEqual(
            EventDeletionConfirmation.title(isRecurring: true),
            String(
                localized: "Delete this occurrence?",
                bundle: .equinox, comment: "Recurring event occurrence deletion confirmation title"
            )
        )
    }

    func testRecurringMeetingResolvesSharedURLOnceAndSkipsOutOfRangeSources() async {
        let calendar = Calendar.equinoxGregorian(timeZone: TimeZone(secondsFromGMT: 0)!)
        let date = CalendarDate(year: 2026, monthIndex: 5, day: 10).date(in: calendar)
        let url = "https://zoom.us/j/123456789"
        let counter = JoinResolutionCounter()
        let sources = (0..<100).map { index in
            makeSource(identifier: "event-\(index)", title: "Meeting", startDate: date,
                       endDate: date.addingTimeInterval(3600), location: url)
        } + [makeSource(identifier: "outside", title: "Outside", startDate: date.addingTimeInterval(-86400),
                        endDate: date.addingTimeInterval(-3600), location: "https://zoom.us/j/999")]
        let events = await DayEventBuilder.buildDayEvents(
            from: sources, rangeStart: date, rangeEnd: date.addingTimeInterval(86400), calendar: calendar,
            resolveNativeJoinURL: { url in await counter.resolve(url) }
        )
        let calls = await counter.calls
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(events.values.flatMap { $0 }.count, 100)
        XCTAssertTrue(events.values.flatMap { $0 }.allSatisfy { $0.joinURL?.absoluteString == url })
    }

    func testShortTeamsMeetingKeepsWebJoinActionThroughEventMapping() async throws {
        let calendar = Calendar.equinoxGregorian(timeZone: TimeZone(secondsFromGMT: 0)!)
        let date = CalendarDate(year: 2026, monthIndex: 8, day: 12).date(in: calendar)
        let url = try XCTUnwrap(URL(string: "https://teams.microsoft.com/meet/1234567890123?p=a%2Bb%2F%3D"))
        let source = makeSource(
            identifier: "teams", title: "Teams meeting", startDate: date,
            endDate: date.addingTimeInterval(3600), location: url.absoluteString
        )
        let events = await DayEventBuilder.buildDayEvents(
            from: [source], rangeStart: date, rangeEnd: date.addingTimeInterval(86400), calendar: calendar,
            resolveNativeJoinURL: { url in
                await NativeJoinURLResolver.resolveNativeJoinURL(from: url, isAppInstalled: { _ in
                    XCTFail("Short Teams URLs must use the original web link without querying installed apps")
                    return true
                })
            }
        )
        XCTAssertEqual(events[date]?.count, 1)
        XCTAssertEqual(events[date]?.first?.joinURL, url)
    }

    private func makeSource(
        identifier: String,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil
    ) -> DayEventSource {
        DayEventSource(
            fields: EventKitEventFields(
                eventIdentifier: identifier,
                calendarItemIdentifier: identifier,
                title: title,
                location: location,
                notes: nil,
                hasNotes: false,
                url: nil,
                startDate: startDate,
                endDate: endDate,
                isAllDay: false,
                calendarIdentifier: "calendar-1",
                calendarTitle: "Work",
                isRecurring: false,
                allowsContentModifications: true,
                participationRawValue: nil
            ),
            calendarColorRed: 1,
            calendarColorGreen: 0,
            calendarColorBlue: 0,
            calendarColorAlpha: 1
        )
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

private actor JoinResolutionCounter {
    private(set) var calls = 0
    func resolve(_ url: URL) -> URL? {
        calls += 1
        return nil
    }
}
