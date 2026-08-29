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
        XCTAssertTrue(CalendarSelectionStorage.hasStoredSelection(in: defaults))
        XCTAssertEqual(CalendarSelectionStorage.loadSelectedIDs(from: defaults), ["cal-a", "cal-b"])
    }

    func testExplicitEmptySelectionIsDifferentFromMissingPreference() {
        CalendarSelectionStorage.saveSelectedIDs([], to: defaults)

        XCTAssertTrue(CalendarSelectionStorage.hasStoredSelection(in: defaults))
        XCTAssertEqual(CalendarSelectionStorage.loadSelectedIDs(from: defaults), [])

        CalendarSelectionStorage.clearSelection(from: defaults)
        XCTAssertFalse(CalendarSelectionStorage.hasStoredSelection(in: defaults))
    }

    func testTemporarilyEmptyStoreDoesNotCreateSelectNonePreference() {
        XCTAssertFalse(
            CalendarSelectionService.shouldPersistSelection(
                discoveredCalendarCount: 0
            )
        )
        XCTAssertFalse(
            CalendarSelectionService.shouldPersistSelection(
                discoveredCalendarCount: 0
            )
        )
        XCTAssertTrue(
            CalendarSelectionService.shouldPersistSelection(
                discoveredCalendarCount: 1
            )
        )
    }

    func testPersistedSelectionKeepsCalendarsMissingFromTransientDiscovery() {
        let ids = CalendarSelectionService.selectionIDsToPersist(
            selectedDiscoveredIDs: ["cal-a"],
            discoveredIDs: ["cal-a", "cal-b"],
            storedSelectedIDs: ["cal-a", "cal-missing"]
        )

        XCTAssertEqual(ids, ["cal-a", "cal-missing"])
    }

    func testDeselectedDiscoveredCalendarIsNotRestoredFromStoredSelection() {
        let ids = CalendarSelectionService.selectionIDsToPersist(
            selectedDiscoveredIDs: [],
            discoveredIDs: ["cal-a"],
            storedSelectedIDs: ["cal-a"]
        )

        XCTAssertTrue(ids.isEmpty)
    }

    func testCalendarSelectionStorageClearRemovesSelection() {
        CalendarSelectionStorage.saveSelectedIDs(["cal-a"], to: defaults)
        CalendarSelectionStorage.clearSelection(from: defaults)
        XCTAssertTrue(CalendarSelectionStorage.loadSelectedIDs(from: defaults).isEmpty)
    }
}
