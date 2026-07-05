import XCTest
@testable import equinox

final class CalendarSelectionServiceTests: XCTestCase {
    override func tearDown() {
        CalendarSelectionStorage.clearSelection()
        super.tearDown()
    }

    func testEmptyServiceHasNoSelectedCalendars() {
        let service = CalendarSelectionService()
        XCTAssertFalse(service.hasSelectedCalendars())
        XCTAssertTrue(service.selectedCalendarIDs().isEmpty)
    }

    func testUpdateSelectedCalendarOnEmptyStorageIsNoOp() {
        var service = CalendarSelectionService()
        service.updateSelectedCalendar(identifier: "missing", selected: true)
        XCTAssertFalse(service.hasSelectedCalendars())
    }

    func testCalendarSelectionStorageRoundTrip() {
        CalendarSelectionStorage.saveSelectedIDs(["cal-a", "cal-b"])
        XCTAssertEqual(CalendarSelectionStorage.loadSelectedIDs(), ["cal-a", "cal-b"])
    }

    func testCalendarSelectionStorageClearRemovesSelection() {
        CalendarSelectionStorage.saveSelectedIDs(["cal-a"])
        CalendarSelectionStorage.clearSelection()
        XCTAssertTrue(CalendarSelectionStorage.loadSelectedIDs().isEmpty)
    }
}
