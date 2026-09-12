import XCTest
@testable import EquinoxKit

final class NewEventDraftValidationTests: XCTestCase {
    private var draft: NewEventDraft {
        NewEventDraft(title: "Meeting", location: "", isAllDay: false,
                      startDate: Date(timeIntervalSince1970: 1_800_000_000),
                      endDate: Date(timeIntervalSince1970: 1_800_003_600), calendarIdentifier: "work")
    }

    func testValidDraftPasses() {
        XCTAssertNoThrow(try draft.validate())
    }

    func testDatesOutsideNavigableYearsAreRejected() throws {
        let calendar = Calendar.equinoxGregorian()
        for year in [1582, 3334, 5000] {
            var invalid = draft
            invalid.startDate = try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: 6, day: 1)))
            invalid.endDate = invalid.startDate.addingTimeInterval(3600)
            XCTAssertFalse(CalendarDate(date: invalid.startDate, calendar: calendar).isValid)
            XCTAssertThrowsError(try invalid.validate(), "A saved event must have a navigable date: \(year)") {
                XCTAssertEqual($0 as? CalendarStoreError, .dateOutsideSupportedRange)
            }
        }
    }

    func testSupportedDateBoundariesUseLocalDaysAndPermitExclusiveEnd() throws {
        for zone in ["UTC", "America/Los_Angeles", "Pacific/Kiritimati"] {
            let calendar = Calendar.equinoxGregorian(timeZone: try XCTUnwrap(TimeZone(identifier: zone)))
            let range = EventDraftDefaults.supportedDateRange(calendar: calendar)
            XCTAssertEqual(CalendarDate(date: range.lowerBound, calendar: calendar), .minimumSupported)
            XCTAssertEqual(CalendarDate(date: range.upperBound, calendar: calendar), .maximumSupported)
            var boundary = draft
            boundary.startDate = CalendarDate.maximumSupported.date(in: calendar)
            boundary.endDate = range.upperBound.addingTimeInterval(1)
            boundary.isAllDay = true
            XCTAssertNoThrow(try boundary.validate(calendar: calendar))
            boundary.endDate = boundary.endDate.addingTimeInterval(1)
            XCTAssertThrowsError(try boundary.validate(calendar: calendar))

            boundary.startDate = range.lowerBound
            boundary.endDate = range.lowerBound.addingTimeInterval(3600)
            boundary.isAllDay = false
            XCTAssertNoThrow(try boundary.validate(calendar: calendar))
            boundary.startDate = range.lowerBound.addingTimeInterval(-1)
            XCTAssertThrowsError(try boundary.validate(calendar: calendar))

            boundary = draft
            boundary.recurrence = RecurrenceDraft(frequency: .yearly, endDate: range.upperBound)
            XCTAssertNoThrow(try boundary.validate(calendar: calendar))
            boundary.recurrence = RecurrenceDraft(frequency: .yearly, endDate: range.upperBound.addingTimeInterval(1))
            XCTAssertThrowsError(try boundary.validate(calendar: calendar))
        }
    }

    func testDefaultDurationAtLastSupportedDayStaysWithinSaveableRange() throws {
        let calendar = Calendar.equinoxGregorian(timeZone: try XCTUnwrap(TimeZone(identifier: "UTC")))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 23, minute: 10)))
        let dates = EventDraftDefaults.defaultStartAndEnd(
            calendar: calendar, initialDate: .maximumSupported, now: now
        )
        var boundary = draft
        boundary.startDate = dates.start
        boundary.endDate = dates.end
        XCTAssertNoThrow(try boundary.validate(calendar: calendar))
        XCTAssertEqual(CalendarDate(date: dates.start, calendar: calendar), .maximumSupported)
        XCTAssertEqual(dates.end.timeIntervalSince(dates.start), 1800)
    }

    func testInvalidDraftsAreRejectedBeforeEventKitMutation() {
        let cases: [(CalendarStoreError, (inout NewEventDraft) -> Void)] = [
            (.emptyTitle, { $0.title = " \n " }),
            (.endDateBeforeStart, { $0.endDate = $0.startDate }),
            (.endDateBeforeStart, { $0.startDate = Date(timeIntervalSince1970: .nan) }),
            (.endDateBeforeStart, { $0.endDate = Date(timeIntervalSince1970: .infinity) }),
            (.invalidURL, { $0.url = URL(string: "relative/path") }),
            (.invalidURL, { $0.url = URL(string: "https://:80/a") }),
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
