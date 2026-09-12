import XCTest
@testable import EquinoxKit

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

    func testMalformedSelectionDoesNotBecomeExplicitSelectNone() {
        defaults.set("invalid", forKey: kSelectedCalendars)
        XCTAssertFalse(CalendarSelectionStorage.hasStoredSelection(in: defaults))
        defaults.set([1, 2], forKey: kSelectedCalendars)
        XCTAssertFalse(CalendarSelectionStorage.hasStoredSelection(in: defaults))
    }

    func testDiscoverySelectionAndTemporaryDisappearanceRoundTrip() {
        var service = CalendarSelectionService(defaults: defaults)
        service.refresh(calendars: [])
        XCTAssertFalse(CalendarSelectionStorage.hasStoredSelection(in: defaults))
        let calendars = [calendar("a", source: ""), calendar("b", source: "Work")]
        service.refresh(calendars: calendars)
        XCTAssertEqual(service.selectedCalendarIDs(), ["a", "b"])
        XCTAssertEqual(service.calendarEntries.first, .source(""))
        service.updateSelectedCalendar(identifier: "a", selected: false)
        service.refresh(calendars: [])
        XCTAssertEqual(CalendarSelectionStorage.loadSelectedIDs(from: defaults), ["b"])
        service.refresh(calendars: calendars)
        XCTAssertEqual(service.selectedCalendarIDs(), ["b"])
        let restored = CalendarSelectionService(defaults: defaults)
        var reloaded = restored
        reloaded.refresh(calendars: calendars)
        XCTAssertEqual(reloaded.selectedCalendarIDs(), ["b"])
    }

    func testExplicitSelectNoneSurvivesDiscoveryAndUnknownToggleDoesNotWrite() {
        CalendarSelectionStorage.saveSelectedIDs([], to: defaults)
        var service = CalendarSelectionService(defaults: defaults)
        service.refresh(calendars: [calendar("a", source: "Work")])
        service.updateSelectedCalendar(identifier: "missing", selected: true)
        XCTAssertFalse(service.hasSelectedCalendars())
        XCTAssertEqual(CalendarSelectionStorage.loadSelectedIDs(from: defaults), [])
        service.updateSelectedCalendar(identifier: "a", selected: true)
        XCTAssertTrue(service.hasSelectedCalendars())
        XCTAssertEqual(service.selectedCalendarIDs(), ["a"])
    }

    private func calendar(_ id: String, source: String) -> SelectableCalendar {
        SelectableCalendar(id: id, title: id, sourceTitle: source, isSelected: false,
                           colorRed: 0, colorGreen: 0, colorBlue: 1, colorAlpha: 1,
                           allowsContentModifications: true)
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
