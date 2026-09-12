import XCTest
@testable import EquinoxKit

@MainActor
final class EventsCoordinatorSyncTests: XCTestCase {
    func testCreateNavigatesBeforeReloadAndMutationsUseFetchQueue() async throws {
        let suite = "equinox.sync.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StubCalendarEventStore()
        let calendar = Calendar.equinoxGregorian()
        let coordinator = EventsCoordinator(
            calendar: calendar, calendarStore: store,
            preferences: PreferencesStore(defaults: defaults)
        )
        let date = CalendarDate(year: 2028, monthIndex: 0, day: 10)
        let start = date.date(in: calendar)
        let draft = NewEventDraft(
            title: "Test", location: "", isAllDay: false,
            startDate: start, endDate: start.addingTimeInterval(3600),
            calendarIdentifier: "work"
        )
        let createError = await coordinator.createEvent(from: draft)
        XCTAssertNil(createError)
        XCTAssertEqual(coordinator.selectedDate, date)
        let range = try XCTUnwrap(store.refetchedRanges.last)
        XCTAssertLessThanOrEqual(range.first, date)
        XCTAssertGreaterThanOrEqual(range.last, date)
        XCTAssertEqual(store.operations.first, "create")
        store.operations = []
        _ = await coordinator.deleteEvent(identifier: "event", occurrenceStartDate: start)
        XCTAssertEqual(store.operations, ["delete", "refetch"])
        store.operations = []
        await coordinator.updateSelectedCalendar(identifier: "work", selected: false)
        XCTAssertEqual(store.operations, ["select", "refetch"])
        store.operations = []
        await coordinator.resetCalendarSelection()
        XCTAssertEqual(store.operations, ["reset", "refetch"])
    }

    func testLateAuthorizedSnapshotCannotOverwriteRevokedAccess() async throws {
        let suite = "equinox.sync.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StubCalendarEventStore()
        let coordinator = EventsCoordinator(
            calendar: Calendar.equinoxGregorian(), calendarStore: store,
            preferences: PreferencesStore(defaults: defaults)
        )
        let suspended = expectation(description: "Old snapshot suspended")
        var resume: CheckedContinuation<CalendarStoreSnapshot, Never>?
        store.readSnapshot = {
            await withCheckedContinuation { continuation in
                resume = continuation
                suspended.fulfill()
            }
        }
        let oldSync = Task { await coordinator.syncFromCalendarStore() }
        await fulfillment(of: [suspended], timeout: 2)
        store.readSnapshot = { StubCalendarEventStore.snapshot(status: .denied) }
        await coordinator.refreshCalendarAccessStatus()
        resume?.resume(returning: StubCalendarEventStore.snapshot(status: .authorized))
        await oldSync.value
        XCTAssertEqual(coordinator.calendarAccessStatus, .denied)
        XCTAssertFalse(coordinator.hasCompletedInitialEventLoad)
        XCTAssertFalse(coordinator.hasSelectedCalendars)
        XCTAssertTrue(coordinator.eventsByDate.isEmpty)
        XCTAssertNil(coordinator.defaultCalendarIdentifierForNewEvents)
    }
}
