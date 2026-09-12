import XCTest
@testable import EquinoxKit

@MainActor
final class AppStateCalendarTests: XCTestCase {
    func testSuccessfulCreateWithFailedReloadDoesNotRepeatMutationOnRetry() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let day = context.appState.events.todayDate
        let start = day.date(in: context.appState.calendar)
        let draft = NewEventDraft(
            title: "Saved meeting", location: "", isAllDay: false,
            startDate: start, endDate: start.addingTimeInterval(3600), calendarIdentifier: "work"
        )
        context.store.refetchResult = false
        context.store.readSnapshot = {
            StubCalendarEventStore.snapshot(status: .authorized, lastFetchError: "Reload failed")
        }

        let error = await context.appState.createEvent(from: draft)
        XCTAssertNil(error, "The save succeeded; reporting a save failure could cause a duplicate event")
        XCTAssertEqual(context.appState.events.lastFetchError, "Reload failed")
        XCTAssertEqual(context.store.operations, ["create", "refetch"])
        XCTAssertFalse(context.appState.events.isFetchingEvents)

        let saved = context.event(start: start, title: draft.title)
        context.store.refetchResult = true
        context.store.readSnapshot = {
            StubCalendarEventStore.snapshot(status: .authorized, events: [day: [saved]])
        }
        let refreshed = expectation(description: "Retry applied the saved event")
        context.appState.events.onEventsSnapshotChanged = { refreshed.fulfill() }
        context.appState.events.retryFetchEvents()
        await fulfillment(of: [refreshed], timeout: 2)
        XCTAssertEqual(context.appState.events.events(for: day), [saved])
        XCTAssertNil(context.appState.events.lastFetchError)
        XCTAssertEqual(context.store.operations, ["create", "refetch", "refetch"])
    }

    func testSuccessfulDeleteClosesDetailsEvenWhenReloadFails() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let day = context.appState.events.todayDate
        let event = context.event(start: day.date(in: context.appState.calendar))
        context.appState.panel.selectedEvent = event
        context.appState.panel.isEventDetailPresented = true
        context.store.refetchResult = false
        context.store.readSnapshot = {
            StubCalendarEventStore.snapshot(status: .authorized, events: [day: [event]], lastFetchError: "Reload failed")
        }

        let error = await context.appState.deleteEvent(identifier: "event", occurrenceStartDate: event.startDate)
        XCTAssertNil(error)
        XCTAssertNil(context.appState.panel.selectedEvent)
        XCTAssertFalse(context.appState.panel.isEventDetailPresented)
        XCTAssertEqual(context.appState.events.lastFetchError, "Reload failed")
        XCTAssertEqual(context.store.operations, ["delete", "refetch"])
    }

    func testIncompleteReloadPreservesDetailsUntilAnAuthoritativeSnapshotArrives() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let day = context.appState.events.todayDate
        let event = context.event(start: day.date(in: context.appState.calendar))
        context.appState.panel.selectedEvent = event
        context.appState.panel.isEventDetailPresented = true
        context.store.readSnapshot = {
            StubCalendarEventStore.snapshot(status: .authorized, hasCompletedInitialLoad: false)
        }

        await context.appState.refreshCalendarAccessStatus()

        XCTAssertEqual(context.appState.panel.selectedEvent, event)
        XCTAssertTrue(context.appState.panel.isEventDetailPresented)
        let updated = context.event(start: event.startDate, title: "Reloaded")
        context.store.readSnapshot = {
            StubCalendarEventStore.snapshot(status: .authorized, events: [day: [updated]])
        }
        await context.appState.refreshCalendarAccessStatus()
        XCTAssertEqual(context.appState.panel.selectedEvent, updated)
        XCTAssertTrue(context.appState.panel.isEventDetailPresented)

        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized) }
        await context.appState.refreshCalendarAccessStatus()
        XCTAssertNil(context.appState.panel.selectedEvent)
        XCTAssertFalse(context.appState.panel.isEventDetailPresented)
    }

    func testInitializationUsesInjectedStoreAndPreferencesWithoutRequestingAccess() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        XCTAssertEqual(context.appState.events.calendarAccessStatus, .authorized)
        XCTAssertEqual(context.appState.events.defaultCalendarIdentifierForNewEvents, "work")
        context.appState.preferences.showDaysWithNoEvents = true
        XCTAssertTrue(context.defaults.bool(forKey: kShowDaysWithNoEventsInAgenda))
        XCTAssertEqual(context.store.accessRequestCount, 0)
        XCTAssertTrue(context.store.operations.isEmpty)
    }

    func testFailedCreateKeepsSelectedDayAndDoesNotReload() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let originalSelection = context.appState.events.selectedDate
        let start = originalSelection.addingDays(90).date(in: context.appState.calendar)
        let draft = NewEventDraft(
            title: "New meeting", location: "", isAllDay: false,
            startDate: start, endDate: start.addingTimeInterval(3600), calendarIdentifier: "work"
        )
        context.store.createError = .readOnlyCalendar

        let error = await context.appState.createEvent(from: draft)

        XCTAssertEqual(error, CalendarStoreError.readOnlyCalendar.localizedDescription)
        XCTAssertEqual(context.appState.events.selectedDate, originalSelection)
        XCTAssertEqual(context.store.operations, ["create"])
        XCTAssertFalse(context.appState.events.isFetchingEvents)
    }

    func testFailedDeleteKeepsEventDetailsOpen() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let event = context.event(start: context.appState.events.todayDate.date(in: context.appState.calendar))
        context.appState.panel.selectedEvent = event
        context.appState.panel.isEventDetailPresented = true
        context.store.deleteError = .eventNotFound

        let error = await context.appState.deleteEvent(identifier: "event", occurrenceStartDate: event.startDate)

        XCTAssertEqual(error, CalendarStoreError.eventNotFound.localizedDescription)
        XCTAssertEqual(context.appState.panel.selectedEvent, event)
        XCTAssertTrue(context.appState.panel.isEventDetailPresented)
        XCTAssertEqual(context.store.operations, ["delete"])
        XCTAssertFalse(context.appState.events.isFetchingEvents)
    }

    func testSuccessfulDeleteClosesOnlyTheSelectedOccurrence() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let day = context.appState.events.todayDate
        let selected = context.event(start: day.date(in: context.appState.calendar))
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: [day: [selected]]) }
        await context.appState.refreshCalendarAccessStatus()
        context.appState.panel.selectedEvent = selected
        context.appState.panel.isEventDetailPresented = true
        let otherOccurrence = selected.startDate.addingTimeInterval(7 * 86400)

        let otherError = await context.appState.deleteEvent(identifier: "event", occurrenceStartDate: otherOccurrence)

        XCTAssertNil(otherError)
        XCTAssertEqual(context.appState.panel.selectedEvent, selected)
        XCTAssertTrue(context.appState.panel.isEventDetailPresented)
        XCTAssertEqual(context.store.deletedOccurrences.last?.start, otherOccurrence)

        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized) }
        let selectedError = await context.appState.deleteEvent(identifier: "event", occurrenceStartDate: selected.startDate)

        XCTAssertNil(selectedError)
        XCTAssertNil(context.appState.panel.selectedEvent)
        XCTAssertFalse(context.appState.panel.isEventDetailPresented)
        XCTAssertEqual(context.store.operations, ["delete", "refetch", "delete", "refetch"])
        XCTAssertEqual(context.store.deletedOccurrences.last?.identifier, "event")
        XCTAssertEqual(context.store.deletedOccurrences.last?.start, selected.startDate)
    }

    func testRevokedAccessClearsCachedEventsMeetingIndicatorAndDetails() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let day = context.appState.events.todayDate
        let event = context.event(start: Date().addingTimeInterval(60))
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: [day: [event]]) }
        await context.appState.refreshCalendarAccessStatus()
        XCTAssertTrue(context.appState.events.shouldShowMeetingIndicator)
        context.appState.panel.selectedEvent = event
        context.appState.panel.isEventDetailPresented = true

        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .denied) }
        await context.appState.refreshCalendarAccessStatus()

        XCTAssertTrue(context.appState.events.eventsByDate.isEmpty)
        XCTAssertFalse(context.appState.events.shouldShowMeetingIndicator)
        XCTAssertFalse(context.appState.events.hasSelectedCalendars)
        XCTAssertFalse(context.appState.events.hasCompletedInitialEventLoad)
        XCTAssertNil(context.appState.panel.selectedEvent)
        XCTAssertFalse(context.appState.panel.isEventDetailPresented)
        XCTAssertEqual(context.store.accessRequestCount, 0)
    }

    func testLateSnapshotCannotRestoreEventsFromDeselectedCalendar() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let day = context.appState.events.todayDate
        let event = context.event(start: day.date(in: context.appState.calendar))
        let oldSnapshot = StubCalendarEventStore.snapshot(status: .authorized, events: [day: [event]])
        context.store.readSnapshot = { oldSnapshot }
        await context.appState.refreshCalendarAccessStatus()
        context.appState.panel.selectedEvent = event
        context.appState.panel.isEventDetailPresented = true
        let suspended = expectation(description: "Old selected-calendar snapshot suspended")
        var resume: CheckedContinuation<CalendarStoreSnapshot, Never>?
        context.store.readSnapshot = {
            await withCheckedContinuation { continuation in
                resume = continuation
                suspended.fulfill()
            }
        }
        let oldSync = Task { await context.appState.refreshCalendarAccessStatus() }
        await fulfillment(of: [suspended], timeout: 2)
        context.store.onSelectionChange = { identifier, selected in
            XCTAssertEqual(identifier, "work")
            XCTAssertFalse(selected)
        }
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, hasSelectedCalendars: false) }

        await context.appState.updateSelectedCalendar(identifier: "work", selected: false)
        resume?.resume(returning: oldSnapshot)
        await oldSync.value

        XCTAssertTrue(context.appState.events.eventsByDate.isEmpty)
        XCTAssertFalse(context.appState.events.hasSelectedCalendars)
        XCTAssertNil(context.appState.panel.selectedEvent)
        XCTAssertFalse(context.appState.panel.isEventDetailPresented)
        XCTAssertEqual(context.store.operations, ["select", "refetch"])
    }

    func testExternalChangeRefreshesSelectedEventDetails() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let day = context.appState.events.todayDate
        let event = context.event(start: day.date(in: context.appState.calendar))
        context.appState.panel.selectedEvent = event
        context.appState.panel.isEventDetailPresented = true
        let updated = context.event(start: event.startDate, title: "Updated meeting")
        context.store.readSnapshot = { StubCalendarEventStore.snapshot(status: .authorized, events: [day: [updated]]) }
        let refreshed = expectation(description: "External change synchronized")
        context.appState.events.onMeetingIndicatorChanged = { refreshed.fulfill() }

        context.store.externalChangeHandler?()
        await fulfillment(of: [refreshed], timeout: 2)

        XCTAssertEqual(context.appState.panel.selectedEvent, updated)
        XCTAssertTrue(context.appState.panel.isEventDetailPresented)
        XCTAssertEqual(context.store.operations, ["refetch"])
        XCTAssertEqual(context.store.accessRequestCount, 1, "The first fetch prepares access through the stub")
    }
}

@MainActor
final class PreferencesResetTests: XCTestCase {
    func testResetUsesInjectedDependenciesAndPersistsPanelState() async throws {
        let suite = "equinox.reset.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = PreferencesStore(defaults: defaults, notificationCenter: NotificationCenter())
        prefs.isPanelPinned = true
        prefs.isPinnedPanelVisible = true
        prefs.clockFormat = "HH:mm"
        var shortcutResets = 0
        var launchResets = 0
        let store = StubCalendarEventStore()
        let state = AppState(calendar: .equinoxGregorian(), calendarStore: store, preferences: prefs,
                             resetShortcuts: { shortcutResets += 1 },
                             disableLaunchAtLogin: { launchResets += 1 })
        await state.waitForInitialization()
        var pinChanges = 0
        state.panel.onPinStateChanged = { pinChanges += 1 }
        let error = await state.resetPreferencesToDefaults()
        XCTAssertNil(error)
        XCTAssertEqual(shortcutResets, 1)
        XCTAssertEqual(launchResets, 1)
        XCTAssertEqual(pinChanges, 1)
        XCTAssertTrue(store.operations.contains("reset"))
        let restored = PreferencesStore(defaults: defaults, notificationCenter: NotificationCenter())
        XCTAssertFalse(restored.isPanelPinned)
        XCTAssertFalse(restored.isPinnedPanelVisible)
        XCTAssertNil(restored.clockFormat)
    }

    func testLaunchAtLoginResetFailureIsReportedAfterOtherSettingsReset() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        let prefs = context.appState.preferences
        prefs.isPinnedPanelVisible = true
        let state = AppState(calendar: .equinoxGregorian(), calendarStore: context.store, preferences: prefs,
                             resetShortcuts: {}, disableLaunchAtLogin: { throw CalendarStoreError.calendarAccessRequired })
        await state.waitForInitialization()
        let error = await state.resetPreferencesToDefaults()
        XCTAssertNotNil(error)
        XCTAssertFalse(prefs.isPinnedPanelVisible)
        XCTAssertTrue(context.store.operations.contains("reset"))
    }
}
