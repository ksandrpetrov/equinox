import XCTest
@testable import EquinoxKit

@MainActor
final class EventsCoordinatorSyncTests: XCTestCase {
    func testAgendaEndpointsAndGridPreferencesFetchTheUpdatedRange() async throws {
        let calendar = Calendar.equinoxGregorian(timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0)))
        let today = CalendarDate(year: 2026, monthIndex: 8, day: 12)
        let gridFirst = CalendarDate(year: 2026, monthIndex: 7, day: 31)
        let gridLast = CalendarDate(year: 2026, monthIndex: 9, day: 11)
        let agendaFirst = CalendarDate(year: 2026, monthIndex: 7, day: 30)
        let agendaLast = CalendarDate(year: 2026, monthIndex: 9, day: 12)
        for showsAgenda in [false, true] {
            let suite = "equinox.fetch-bounds.tests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let preferences = PreferencesStore(defaults: defaults, notificationCenter: NotificationCenter())
            preferences.showsAgenda = showsAgenda
            preferences.weekStartWeekday = 1
            preferences.calendarRowCount = 6
            let store = StubCalendarEventStore()
            let events = EventsCoordinator(calendar: calendar, calendarStore: store, preferences: preferences,
                                           now: { today.date(in: calendar) }, navigationDelay: {})
            defer { events.onEventsSnapshotChanged = {} }
            events.updateAgendaVisibleRange(first: agendaFirst, last: agendaLast)
            // A reversed update must preserve the previous valid agenda bounds.
            events.updateAgendaVisibleRange(first: agendaLast, last: agendaFirst)
            let range = events.fetchRange(coveringGridFrom: gridFirst, through: gridLast)
            XCTAssertEqual(range.first, showsAgenda ? agendaFirst : gridFirst)
            XCTAssertEqual(range.last, showsAgenda ? agendaLast : gridLast)
            XCTAssertTrue(store.fetchedRanges.isEmpty)
            XCTAssertTrue(store.refetchedRanges.isEmpty, "No grid has been presented yet")
            if !showsAgenda {
                // The first Today request must load the current month even when
                // neither the month nor selected day changes and agenda is hidden.
                let loaded = expectation(description: "First Today loads the visible grid")
                var snapshots = 0
                events.onEventsSnapshotChanged = {
                    snapshots += 1
                    if snapshots == 1 { loaded.fulfill() }
                    else { XCTFail("The first Today request must fetch once") }
                }
                events.goToToday()
                await fulfillment(of: [loaded], timeout: 2)
                XCTAssertEqual(store.fetchedRanges.count, 1)
                XCTAssertEqual(store.fetchedRanges.first?.first, gridFirst)
                XCTAssertEqual(store.fetchedRanges.first?.last, gridLast)
                XCTAssertTrue(store.refetchedRanges.isEmpty)
                XCTAssertEqual(events.agendaScrollToken, 1)
                continue
            }

            let initialized = expectation(description: "Initial grid and agenda range loaded")
            var initialSnapshots = 0
            events.onEventsSnapshotChanged = {
                initialSnapshots += 1
                if initialSnapshots == 1 { initialized.fulfill() }
                else { XCTFail("Initial presentation must fetch once") }
            }
            events.refreshForPanelPresentation()
            await fulfillment(of: [initialized], timeout: 2)
            XCTAssertEqual(store.refetchedRanges.count, 1)
            XCTAssertEqual(store.refetchedRanges.first?.first, agendaFirst)
            XCTAssertEqual(store.refetchedRanges.first?.last, agendaLast)

            let earlier = CalendarDate(year: 2026, monthIndex: 7, day: 29)
            let later = CalendarDate(year: 2026, monthIndex: 9, day: 13)
            let tallerGridLast = CalendarDate(year: 2026, monthIndex: 9, day: 18)
            let changes: [(first: CalendarDate, last: CalendarDate, apply: @MainActor () -> Void)] = [
                (earlier, agendaLast, { events.updateAgendaVisibleRange(first: earlier, last: agendaLast) }),
                (earlier, later, { events.updateAgendaVisibleRange(first: earlier, last: later) }),
                (earlier, tallerGridLast, { preferences.calendarRowCount = 7 })
            ]
            for (index, change) in changes.enumerated() {
                let fetched = expectation(description: "Range change \(index) synchronized")
                var snapshots = 0
                events.onEventsSnapshotChanged = {
                    snapshots += 1
                    if snapshots == 1 { fetched.fulfill() }
                    else { XCTFail("One range change must fetch once") }
                }
                change.apply()
                await fulfillment(of: [fetched], timeout: 2)
                XCTAssertEqual(store.fetchedRanges.count, index + 1)
                XCTAssertEqual(store.fetchedRanges.last?.first, change.first)
                XCTAssertEqual(store.fetchedRanges.last?.last, change.last)
            }
            XCTAssertEqual(store.refetchedRanges.count, 1, "Range expansion must preserve cached events")
            XCTAssertEqual(events.selectedDate, today)
            XCTAssertEqual(events.monthDate, today)
            XCTAssertEqual(events.agendaScrollToken, 0)
            let visibleDay = today.addingDays(1)
            events.syncSelectionFromAgendaScroll(visibleDay)
            XCTAssertEqual(events.selectedDate, visibleDay, "Manual agenda scroll must update the calendar selection")
            XCTAssertEqual(events.monthDate, today)
            XCTAssertEqual(events.agendaScrollToken, 0, "Synchronizing selection must not initiate another scroll")
        }
    }

    func testTimeRefreshUpdatesPresentationAndReloadsWithoutMovingSelection() async throws {
        for significantChange in [false, true] {
            let context = try CalendarTestContext()
            defer { context.cleanUp() }
            await context.finishInitialization()
            let events = context.appState.events
            let today = events.todayDate
            let month = events.monthDate
            let token = events.agendaScrollToken
            let meeting = context.event(start: context.now.addingTimeInterval(60))
            let snapshot = StubCalendarEventStore.snapshot(status: .authorized, events: [today: [meeting]])
            context.store.readSnapshot = { snapshot }
            events.eventsByDate = [today: [meeting]]
            events.todayDate = today.addingDays(-1)
            events.currentTime = context.now.addingTimeInterval(-600)
            var indicatorUpdates: [Bool] = []
            events.onMeetingIndicatorChanged = { indicatorUpdates.append(events.shouldShowMeetingIndicator) }
            let refreshed = expectation(description: "Time change reloads the current event range")
            let expectedSnapshots = significantChange ? 2 : 1
            refreshed.expectedFulfillmentCount = expectedSnapshots
            var snapshots = 0
            events.onEventsSnapshotChanged = {
                snapshots += 1
                if snapshots <= expectedSnapshots {
                    refreshed.fulfill()
                } else {
                    XCTFail("A time change must not produce extra snapshots")
                }
            }
            defer {
                events.onMeetingIndicatorChanged = {}
                events.onEventsSnapshotChanged = {}
            }

            if significantChange {
                events.refreshAfterSignificantTimeChange()
            } else {
                events.refreshTodayAndMeetingIndicator()
            }

            XCTAssertEqual(events.currentTime, context.now)
            XCTAssertEqual(events.todayDate, today)
            XCTAssertTrue(events.shouldShowMeetingIndicator)
            XCTAssertEqual(indicatorUpdates, [true], "Presentation must update before the async reload")
            await fulfillment(of: [refreshed], timeout: 2)
            XCTAssertEqual(snapshots, expectedSnapshots)
            XCTAssertEqual(context.store.operations, ["refetch"])
            XCTAssertEqual(context.store.timeInvalidationCount, significantChange ? 1 : 0)
            XCTAssertEqual(context.store.accessRequestCount, 1)
            XCTAssertEqual(events.eventsByDate[today], [meeting])
            XCTAssertEqual(events.selectedDate, today)
            XCTAssertEqual(events.monthDate, month)
            XCTAssertEqual(events.agendaScrollToken, token)
        }
    }

    func testAgendaRefocusWaitsForSuccessfulFetchAndIsConsumedOnce() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let events = context.appState.events
        context.appState.panel.isPanelVisible = true
        events.selectDate(events.selectedDate)
        let requestedToken = events.agendaScrollToken

        await events.refreshCalendarAccessStatus()
        XCTAssertEqual(events.agendaScrollToken, requestedToken, "A snapshot read is not a completed fetch")

        context.store.refetchResult = false
        await events.resetCalendarSelection()
        XCTAssertEqual(events.agendaScrollToken, requestedToken, "A failed fetch must keep the pending focus")

        context.store.refetchResult = true
        await events.resetCalendarSelection()
        XCTAssertEqual(events.agendaScrollToken, requestedToken + 1)

        await events.resetCalendarSelection()
        XCTAssertEqual(events.agendaScrollToken, requestedToken + 1, "Background refresh must not scroll again")
    }

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
