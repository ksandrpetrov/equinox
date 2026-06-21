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
}
