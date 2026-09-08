import XCTest
@testable import equinox

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

@MainActor
private final class StubCalendarEventStore: CalendarEventStore {
    var operations: [String] = []
    var refetchedRanges: [(first: CalendarDate, last: CalendarDate)] = []
    var readSnapshot: @MainActor () async -> CalendarStoreSnapshot = { snapshot(status: .authorized) }

    static func snapshot(status: CalendarAccessStatus) -> CalendarStoreSnapshot {
        CalendarStoreSnapshot(
            accessStatus: status, eventsByDate: [:], calendarEntries: [],
            defaultCalendarIdentifier: status.isAuthorized ? "work" : nil,
            hasSelectedCalendars: status.isAuthorized, lastFetchError: nil,
            hasCompletedInitialLoad: status.isAuthorized
        )
    }
    func snapshot() async -> CalendarStoreSnapshot { await readSnapshot() }
    func setExternalChangeHandler(_ handler: @escaping @Sendable () -> Void) async {}
    func requestCalendarAccessIfNeeded() async -> Bool { true }
    func fetchEvents(first: CalendarDate, last: CalendarDate, refetch: Bool) async -> Bool { true }
    func refetchAll(first: CalendarDate, last: CalendarDate) async -> Bool {
        operations.append("refetch")
        refetchedRanges.append((first, last))
        return true
    }
    func invalidateTimeContext() async {}
    func createEvent(from draft: NewEventDraft) async throws { operations.append("create") }
    func deleteEvent(identifier: String, occurrenceStartDate: Date) async throws { operations.append("delete") }
    func updateSelectedCalendar(identifier: String, selected: Bool) async { operations.append("select") }
    func resetCalendarSelection() async { operations.append("reset") }
}

@MainActor
final class EventFetchCoordinatorTests: XCTestCase {
    func testSupersededPendingRequestDoesNotReportSuccessfulFetch() async {
        let day = CalendarDate(year: 2026, monthIndex: 0, day: 1)
        var release: CheckedContinuation<Void, Never>?
        var fetchCalls = 0
        let coordinator = EventFetchCoordinator(
            requestCalendarAccess: { true },
            fetchEvents: { _, _ in
                fetchCalls += 1
                if fetchCalls == 1 {
                    await withCheckedContinuation { release = $0 }
                }
                return true
            },
            refetchEvents: { _, _ in true }
        )
        let active = Task { await coordinator.fetch(range: (day, day)) }
        await waitUntil { release != nil }
        let pendingStarted = expectation(description: "Pending request enqueued")
        let pending = Task {
            pendingStarted.fulfill()
            return await coordinator.fetch(range: (day.addingDays(1), day.addingDays(2)))
        }
        await fulfillment(of: [pendingStarted], timeout: 2)
        let distant = CalendarDate.maximumSupported
        coordinator.scheduleFetch(range: (distant, distant))
        let supersededSucceeded = await pending.value
        XCTAssertFalse(supersededSucceeded)
        release?.resume()
        let activeSucceeded = await active.value
        XCTAssertTrue(activeSucceeded)
        await waitUntil { fetchCalls == 2 }
    }

    func testSerializesFetchesCoalescesPendingRangesAndKeepsLateDataVisible() async {
        let firstRange = (
            first: CalendarDate(year: 2026, monthIndex: 7, day: 1),
            last: CalendarDate(year: 2026, monthIndex: 7, day: 7)
        )
        let secondRange = (
            first: CalendarDate(year: 2026, monthIndex: 6, day: 20),
            last: CalendarDate(year: 2026, monthIndex: 7, day: 15)
        )
        let thirdRange = (
            first: CalendarDate(year: 2026, monthIndex: 6, day: 15),
            last: CalendarDate(year: 2026, monthIndex: 8, day: 1)
        )

        var operations: [String] = []
        var cachedDates = Set<CalendarDate>()
        var syncedSnapshots: [Set<CalendarDate>] = []
        var releaseFirstFetch: CheckedContinuation<Void, Never>?

        let coordinator = EventFetchCoordinator(
            requestCalendarAccess: {
                operations.append("access")
                return true
            },
            fetchEvents: { first, last in
                operations.append("fetch:\(first.julian)-\(last.julian)")
                await withCheckedContinuation { continuation in
                    releaseFirstFetch = continuation
                }
                cachedDates.insert(firstRange.first)
                return true
            },
            refetchEvents: { first, last in
                operations.append("refetch:\(first.julian)-\(last.julian)")
                cachedDates = [firstRange.first, first, last]
                return true
            }
        )
        coordinator.onSyncComplete = { successfulFetch in
            XCTAssertTrue(successfulFetch)
            syncedSnapshots.append(cachedDates)
        }

        let firstTask = Task {
            await coordinator.fetch(range: firstRange)
        }
        await waitUntil { releaseFirstFetch != nil }

        coordinator.scheduleFetch(range: secondRange)
        coordinator.scheduleFetch(range: thirdRange, refetch: true)

        XCTAssertEqual(
            operations,
            ["access", "fetch:\(firstRange.first.julian)-\(firstRange.last.julian)"],
            "pending work must not start while the first fetch is suspended"
        )

        releaseFirstFetch?.resume()
        let firstSucceeded = await firstTask.value
        XCTAssertTrue(firstSucceeded)
        await waitUntil { syncedSnapshots.count == 2 }

        XCTAssertEqual(
            operations.last,
            "refetch:\(thirdRange.first.julian)-\(thirdRange.last.julian)",
            "pending ranges must be unioned and upgraded to refetch"
        )
        XCTAssertEqual(syncedSnapshots.count, 2)
        XCTAssertTrue(
            syncedSnapshots.first?.contains(firstRange.first) == true,
            "every successful commit must synchronize its snapshot with the UI"
        )
        XCTAssertTrue(
            syncedSnapshots.last?.contains(firstRange.first) == true,
            "data committed by the slower first fetch must reach the final UI snapshot"
        )
    }

    func testAccessFailureSkipsFetchButStillSynchronizesPresentation() async {
        var didFetch = false
        var syncResults: [Bool] = []
        let date = CalendarDate(year: 2026, monthIndex: 7, day: 1)
        let coordinator = EventFetchCoordinator(
            requestCalendarAccess: { false },
            fetchEvents: { _, _ in
                didFetch = true
                return true
            },
            refetchEvents: { _, _ in
                didFetch = true
                return true
            }
        )
        coordinator.onSyncComplete = { success in
            syncResults.append(success)
        }

        let success = await coordinator.fetch(
            range: (date, date),
            refetch: true,
            preparesCalendarAccess: true
        )

        XCTAssertFalse(success)
        XCTAssertFalse(didFetch)
        XCTAssertEqual(syncResults, [false])
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<1_000 {
            if condition() {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for asynchronous state", file: file, line: line)
    }
}

final class AgendaContentStateTests: XCTestCase {
    func testAgendaStaysHiddenUntilCalendarAccessIsAuthorized() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .notDetermined,
                hasCompletedInitialLoad: false,
                hasFetchError: false,
                hasVisibleEvents: false
            ),
            .hidden
        )
    }

    func testAgendaHidesWhenNoCalendarsAreSelected() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: true,
                hasFetchError: false,
                hasVisibleEvents: true,
                hasSelectedCalendars: false
            ),
            .hidden
        )
    }

    func testInitialAuthorizedAgendaShowsLoadingInsteadOfEmptyContent() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: false,
                hasFetchError: false,
                hasVisibleEvents: false
            ),
            .loading
        )
    }

    func testSuccessfulEmptyFetchShowsEmptyState() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: true,
                hasFetchError: false,
                hasVisibleEvents: false
            ),
            .empty
        )
    }

    func testCachedContentRemainsVisibleDuringRefreshError() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: true,
                hasFetchError: true,
                hasVisibleEvents: true
            ),
            .content
        )
    }

    func testInitialFetchErrorWithoutCacheHidesAgendaContent() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: false,
                hasFetchError: true,
                hasVisibleEvents: false
            ),
            .hidden
        )
    }

    func testAgendaHidesCachedEventsAfterAccessIsRevoked() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .denied,
                hasCompletedInitialLoad: true,
                hasFetchError: false,
                hasVisibleEvents: true
            ),
            .hidden
        )
    }
}

final class PanelStateOverlayContentTests: XCTestCase {
    func testAuthorizedInitialLoadDoesNotShowFalseNoCalendarsState() {
        XCTAssertEqual(
            PanelStateOverlayContent.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: false,
                fetchError: nil,
                hasCalendars: false,
                hasSelectedCalendars: false
            ),
            .none
        )
    }

    func testCompletedLoadDistinguishesUnavailableAndUnselectedCalendars() {
        XCTAssertEqual(
            PanelStateOverlayContent.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: true,
                fetchError: nil,
                hasCalendars: false,
                hasSelectedCalendars: false
            ),
            .noCalendarsAvailable
        )
        XCTAssertEqual(
            PanelStateOverlayContent.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: true,
                fetchError: nil,
                hasCalendars: true,
                hasSelectedCalendars: false
            ),
            .noCalendarsSelected
        )
    }

    func testPermissionAndFetchErrorsTakePriority() {
        XCTAssertEqual(
            PanelStateOverlayContent.resolve(
                accessStatus: .denied,
                hasCompletedInitialLoad: true,
                fetchError: "stale error",
                hasCalendars: true,
                hasSelectedCalendars: true
            ),
            .permission
        )
        XCTAssertEqual(
            PanelStateOverlayContent.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: false,
                fetchError: "fetch failed",
                hasCalendars: false,
                hasSelectedCalendars: false
            ),
            .fetchError("fetch failed")
        )
    }
}

final class DateFormattersTests: XCTestCase {
    func testLocaleNotificationCanInvalidateFormattersWithoutChangingLocaleIdentifier() {
        let first = EquinoxFormatters.formatter(key: "test.locale-overrides") { $0.dateFormat = "HH" }
        EquinoxFormatters.invalidateCache()
        let second = EquinoxFormatters.formatter(key: "test.locale-overrides") { $0.dateFormat = "hh" }
        XCTAssertFalse(first === second)
        XCTAssertEqual(second.dateFormat, "hh")
    }

    func testRelativeTimeNeverShowsZeroMinutes() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let eventStart = now.addingTimeInterval(15)
        let expected = String(
            format: String(localized: "in %lld min", comment: "Relative event time"),
            1
        )

        XCTAssertEqual(
            EquinoxFormatters.relativeTime(until: eventStart, from: now),
            expected
        )
    }

    func testCachedFormattersUseAutoupdatingSystemTimeZone() {
        let formatter = EquinoxFormatters.formatter(key: "test.autoupdating-time-zone") {
            $0.timeStyle = .short
        }

        XCTAssertEqual(formatter.timeZone.identifier, TimeZone.autoupdatingCurrent.identifier)
    }

    func testFormatterKeepsGregorianYearForNonGregorianLocale() {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let formatter = EquinoxFormatters.makeFormatter(
            locale: Locale(identifier: "ja_JP@calendar=japanese"),
            timeZone: timeZone
        ) {
            $0.dateFormat = "yyyy"
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 30))!

        XCTAssertEqual(formatter.calendar.identifier, .gregorian)
        XCTAssertEqual(formatter.string(from: date), "2026")
    }
}

@MainActor
final class URLOpenerTests: XCTestCase {
    func testUnavailableNativeAppFallsBackToWebURL() throws {
        let native = try XCTUnwrap(URL(string: "zoommtg://zoom.us/join?confno=123"))
        let web = try XCTUnwrap(URL(string: "https://zoom.us/j/123"))
        var opened: [URL] = []
        XCTAssertTrue(URLOpener.open(native, fallback: web, using: { url in
            opened.append(url)
            return url == web
        }))
        XCTAssertEqual(opened, [native, web])
    }

    func testSuccessfulOpenDoesNotLaunchFallbackAndFailedDuplicateIsNotRetried() throws {
        let url = try XCTUnwrap(URL(string: "https://zoom.us/j/123"))
        var calls = 0
        XCTAssertTrue(URLOpener.open(url, fallback: url, using: { _ in calls += 1; return true }))
        XCTAssertEqual(calls, 1)
        calls = 0
        XCTAssertFalse(URLOpener.open(url, fallback: url, using: { _ in calls += 1; return false }))
        XCTAssertEqual(calls, 1)
    }
}
