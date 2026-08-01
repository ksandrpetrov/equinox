import XCTest
@testable import equinox

final class CalendarSelectionServiceTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "CalendarSelectionServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testEmptyServiceHasNoSelectedCalendars() {
        let service = CalendarSelectionService(defaults: defaults)
        XCTAssertFalse(service.hasSelectedCalendars())
        XCTAssertTrue(service.selectedCalendarIDs().isEmpty)
    }

    func testUpdateSelectedCalendarOnEmptyStorageIsNoOp() {
        var service = CalendarSelectionService(defaults: defaults)
        service.updateSelectedCalendar(identifier: "missing", selected: true)
        XCTAssertFalse(service.hasSelectedCalendars())
    }

    func testCalendarSelectionStorageRoundTrip() {
        CalendarSelectionStorage.saveSelectedIDs(["cal-a", "cal-b"], to: defaults)
        XCTAssertEqual(CalendarSelectionStorage.loadSelectedIDs(from: defaults), ["cal-a", "cal-b"])
    }

    func testCalendarSelectionStorageClearRemovesSelection() {
        CalendarSelectionStorage.saveSelectedIDs(["cal-a"], to: defaults)
        CalendarSelectionStorage.clearSelection(from: defaults)
        XCTAssertTrue(CalendarSelectionStorage.loadSelectedIDs(from: defaults).isEmpty)
    }
}
