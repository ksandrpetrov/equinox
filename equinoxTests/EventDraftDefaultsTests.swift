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

    func testDefaultStartRoundsToHourBoundary() {
        let initial = CalendarDate(year: 2026, monthIndex: 5, day: 21)
        let (start, _) = EventDraftDefaults.defaultStartAndEnd(calendar: calendar, initialDate: initial)
        XCTAssertEqual(calendar.component(.minute, from: start), 0)
        XCTAssertEqual(calendar.component(.second, from: start), 0)
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
        XCTAssertEqual(calendar.component(.minute, from: start), 0)
    }

    func testAlertOffsetTwoDaysBefore() {
        XCTAssertEqual(EventDraftDefaults.alertOffset(forPickerIndex: 9), -172_800)
    }
}
