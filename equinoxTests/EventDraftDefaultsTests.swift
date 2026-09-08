import XCTest
@testable import equinox

final class EventDraftDefaultsTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    func testDefaultStartAndEndSpanOneHour() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let initial = CalendarDate(year: 2026, monthIndex: 5, day: 21)
        let (start, end) = EventDraftDefaults.defaultStartAndEnd(calendar: cal, initialDate: initial)
        XCTAssertEqual(cal.dateComponents([.minute], from: start, to: end).minute, 60)
        XCTAssertEqual(cal.component(.day, from: start), 21)
    }

    func testRecurrenceDraftMapsPickerIndices() {
        let endDate = Date(timeIntervalSince1970: 0)
        XCTAssertNil(EventDraftDefaults.recurrenceDraft(fromIndex: 0, endDateIndex: 0, endDate: endDate))
        XCTAssertEqual(EventDraftDefaults.recurrenceDraft(fromIndex: 1, endDateIndex: 0, endDate: endDate)?.frequency, .daily)
        XCTAssertEqual(EventDraftDefaults.recurrenceDraft(fromIndex: 3, endDateIndex: 0, endDate: endDate)?.frequency, .biweekly)
        XCTAssertEqual(EventDraftDefaults.recurrenceDraft(fromIndex: 5, endDateIndex: 0, endDate: endDate)?.frequency, .yearly)
    }

    func testRecurrenceDraftIncludesEndDateWhenSelected() {
        let endDate = Date(timeIntervalSince1970: 100)
        let draft = EventDraftDefaults.recurrenceDraft(fromIndex: 2, endDateIndex: 1, endDate: endDate)
        XCTAssertEqual(draft?.endDate, endDate)
    }

    func testAlertOffsetReturnsNilForNone() {
        XCTAssertNil(EventDraftDefaults.alertOffset(forPickerIndex: 0))
    }

    func testAlertOffsetReturnsZeroForAtTimeOfEvent() {
        XCTAssertEqual(EventDraftDefaults.alertOffset(forPickerIndex: 1), 0)
    }

    func testAlertOffsetReturnsNegativeOffsets() {
        XCTAssertEqual(EventDraftDefaults.alertOffset(forPickerIndex: 2), -300)
        XCTAssertEqual(EventDraftDefaults.alertOffset(forPickerIndex: 5), -1800)
    }

    func testDefaultStartRoundsToHalfHourBoundary() {
        let initial = CalendarDate(year: 2026, monthIndex: 5, day: 21)
        let (start, _) = EventDraftDefaults.defaultStartAndEnd(calendar: calendar, initialDate: initial)
        XCTAssertTrue([0, 30].contains(calendar.component(.minute, from: start)))
        XCTAssertEqual(calendar.component(.second, from: start), 0)
    }

    func testDefaultStartRoundsUpInsteadOfIntoThePast() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 10, minute: 1))!
        let initial = CalendarDate(year: 2026, monthIndex: 5, day: 21)

        let (start, end) = EventDraftDefaults.defaultStartAndEnd(
            calendar: calendar,
            initialDate: initial,
            now: now
        )

        XCTAssertEqual(calendar.dateComponents([.hour, .minute], from: start).hour, 10)
        XCTAssertEqual(calendar.dateComponents([.hour, .minute], from: start).minute, 30)
        XCTAssertGreaterThanOrEqual(start, now)
        XCTAssertEqual(end.timeIntervalSince(start), 60 * 60)
    }

    func testDefaultStartKeepsExactHalfHourBoundary() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 10, minute: 30))!
        let initial = CalendarDate(year: 2026, monthIndex: 5, day: 21)

        let (start, _) = EventDraftDefaults.defaultStartAndEnd(
            calendar: calendar,
            initialDate: initial,
            now: now
        )

        XCTAssertEqual(start, now)
    }

    func testDefaultStartRollsLateTodayIntoTomorrow() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 23, minute: 50))!
        let initial = CalendarDate(year: 2026, monthIndex: 5, day: 21)

        let (start, _) = EventDraftDefaults.defaultStartAndEnd(
            calendar: calendar,
            initialDate: initial,
            now: now
        )

        XCTAssertEqual(
            calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start),
            DateComponents(year: 2026, month: 6, day: 22, hour: 0, minute: 0)
        )
    }

    func testChangingStartPreservesPositiveDuration() {
        let previousStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 9))!
        let previousEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 10, minute: 30))!
        let newStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 13))!

        let newEnd = EventDraftDefaults.endDatePreservingDuration(
            previousStart: previousStart,
            previousEnd: previousEnd,
            newStart: newStart,
            calendar: calendar
        )

        XCTAssertEqual(newEnd.timeIntervalSince(newStart), 90 * 60)
    }

    func testChangingStartFallsBackToOneHourForInvalidDuration() {
        let previousStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 10))!
        let previousEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 9))!
        let newStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 13))!

        let newEnd = EventDraftDefaults.endDatePreservingDuration(
            previousStart: previousStart,
            previousEnd: previousEnd,
            newStart: newStart,
            calendar: calendar
        )

        XCTAssertEqual(newEnd.timeIntervalSince(newStart), 60 * 60)
    }

    func testRecurrenceDraftMapsMonthlyPickerIndex() {
        let endDate = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(EventDraftDefaults.recurrenceDraft(fromIndex: 4, endDateIndex: 0, endDate: endDate)?.frequency, .monthly)
    }

    func testRecurrenceDraftOmitsEndDateWhenNotSelected() {
        let endDate = Date(timeIntervalSince1970: 100)
        let draft = EventDraftDefaults.recurrenceDraft(fromIndex: 2, endDateIndex: 0, endDate: endDate)
        XCTAssertNil(draft?.endDate)
    }

    func testAlertOffsetReturnsNilForOutOfRangeIndex() {
        XCTAssertNil(EventDraftDefaults.alertOffset(forPickerIndex: -1))
        XCTAssertNil(EventDraftDefaults.alertOffset(forPickerIndex: 99))
    }

    func testDefaultStartAndEndWithoutInitialDateSpansOneHour() {
        let (start, end) = EventDraftDefaults.defaultStartAndEnd(calendar: calendar, initialDate: nil)
        XCTAssertEqual(calendar.dateComponents([.minute], from: start, to: end).minute, 60)
        XCTAssertTrue([0, 30].contains(calendar.component(.minute, from: start)))
    }

    func testAlertOffsetTwoDaysBefore() {
        XCTAssertEqual(EventDraftDefaults.alertOffset(forPickerIndex: 9), -172_800)
    }

    func testSingleDayAllDayDatesUseMidnightAndExclusiveEnd() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 14))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 15))!

        let normalized = EventDraftDefaults.normalizedDates(
            calendar: calendar,
            start: start,
            end: end,
            isAllDay: true
        )

        XCTAssertEqual(calendar.dateComponents([.hour], from: normalized!.start).hour, 0)
        XCTAssertEqual(calendar.dateComponents([.day], from: normalized!.start, to: normalized!.end).day, 1)
    }

    func testAllDayNormalizationIsCalendarAwareAcrossDST() {
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let date = losAngeles.date(from: DateComponents(year: 2025, month: 3, day: 9, hour: 12))!

        let normalized = EventDraftDefaults.normalizedDates(
            calendar: losAngeles,
            start: date,
            end: date,
            isAllDay: true
        )!

        XCTAssertEqual(losAngeles.component(.day, from: normalized.start), 9)
        XCTAssertEqual(losAngeles.component(.day, from: normalized.end), 10)
        XCTAssertEqual(normalized.end.timeIntervalSince(normalized.start), 23 * 60 * 60)
    }

    func testAllDayEndBeforeStartIsRejected() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 22))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21))!
        XCTAssertNil(EventDraftDefaults.normalizedDates(calendar: calendar, start: start, end: end, isAllDay: true))
    }

    func testEventURLMustBeAbsolute() {
        XCTAssertNil(EventDraftDefaults.absoluteURL(from: "zoom.us/j/123"))
        XCTAssertNil(EventDraftDefaults.absoluteURL(from: "https:///missing-host"))
        XCTAssertEqual(EventDraftDefaults.absoluteURL(from: "https://zoom.us/j/123")?.host(), "zoom.us")
        XCTAssertEqual(EventDraftDefaults.absoluteURL(from: "tel:+123")?.scheme, "tel")
    }

    func testRecurrenceEndCoversTheSelectedCalendarDay() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 18))!
        let selectedEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 8))!
        let normalized = EventDraftDefaults.normalizedRecurrenceEnd(
            calendar: calendar,
            eventStart: start,
            selectedEnd: selectedEnd
        )!

        XCTAssertEqual(calendar.component(.day, from: normalized), 21)
        XCTAssertEqual(calendar.component(.hour, from: normalized), 23)
        XCTAssertGreaterThan(normalized, start)
    }

    func testRecurrenceEndBeforeEventDayIsRejected() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 22))!
        let selectedEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21))!
        XCTAssertNil(
            EventDraftDefaults.normalizedRecurrenceEnd(
                calendar: calendar,
                eventStart: start,
                selectedEnd: selectedEnd
            )
        )
    }

    func testPreferredCalendarKeepsCurrentSelection() {
        XCTAssertEqual(
            EventDraftDefaults.preferredCalendarIdentifier(
                currentIdentifier: "work",
                defaultIdentifier: "personal",
                availableIdentifiers: ["personal", "work"]
            ),
            "work"
        )
    }

    func testPreferredCalendarUsesSystemDefaultThenFirstFallback() {
        XCTAssertEqual(
            EventDraftDefaults.preferredCalendarIdentifier(
                currentIdentifier: "missing",
                defaultIdentifier: "work",
                availableIdentifiers: ["personal", "work"]
            ),
            "work"
        )
        XCTAssertEqual(
            EventDraftDefaults.preferredCalendarIdentifier(
                currentIdentifier: "missing",
                defaultIdentifier: nil,
                availableIdentifiers: ["personal", "work"]
            ),
            "personal"
        )
        XCTAssertEqual(
            EventDraftDefaults.preferredCalendarIdentifier(
                currentIdentifier: "missing",
                defaultIdentifier: "work",
                availableIdentifiers: []
            ),
            ""
        )
    }
}

final class NewEventDraftValidationTests: XCTestCase {
    private var draft: NewEventDraft {
        NewEventDraft(title: "Meeting", location: "", isAllDay: false,
                      startDate: Date(timeIntervalSince1970: 1_800_000_000),
                      endDate: Date(timeIntervalSince1970: 1_800_003_600), calendarIdentifier: "work")
    }

    func testValidDraftPasses() {
        XCTAssertNoThrow(try draft.validate())
    }

    func testInvalidDraftsAreRejectedBeforeEventKitMutation() {
        let cases: [(CalendarStoreError, (inout NewEventDraft) -> Void)] = [
            (.emptyTitle, { $0.title = " \n " }),
            (.endDateBeforeStart, { $0.endDate = $0.startDate }),
            (.endDateBeforeStart, { $0.startDate = Date(timeIntervalSince1970: .nan) }),
            (.endDateBeforeStart, { $0.endDate = Date(timeIntervalSince1970: .infinity) }),
            (.invalidURL, { $0.url = URL(string: "relative/path") }),
            (.invalidRecurrenceEnd, { $0.recurrence = RecurrenceDraft(frequency: .daily, endDate: $0.startDate.addingTimeInterval(-1)) }),
            (.invalidAlert, { $0.alertOffset = .infinity }),
        ]
        for (expected, mutate) in cases {
            var invalid = draft
            mutate(&invalid)
            XCTAssertThrowsError(try invalid.validate()) { error in
                XCTAssertEqual(error as? CalendarStoreError, expected)
            }
        }
    }

    func testNonFiniteDatesAreRejectedBeforeAllDayNormalization() {
        for allDay in [false, true] {
            XCTAssertNil(EventDraftDefaults.normalizedDates(
                calendar: Calendar.equinoxGregorian(), start: draft.startDate,
                end: Date(timeIntervalSince1970: .infinity), isAllDay: allDay
            ))
        }
    }
}
