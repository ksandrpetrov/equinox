import XCTest
@testable import equinox

final class EventsCoordinatorSyncTests: XCTestCase {
    func testEventMutationsReloadThroughFetchCoordinator() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repoRoot.appendingPathComponent("equinox/App/EventsCoordinator.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let reloadCount = source.components(separatedBy: "_ = await reloadCurrentEvents()").count - 1

        XCTAssertEqual(reloadCount, 4, "create, delete, selection-on, and reset must reload through the fetch queue")
    }

    func testCreateNavigatesBeforeReloadingEvents() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repoRoot.appendingPathComponent("equinox/App/EventsCoordinator.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let createBody = try XCTUnwrap(
            source.components(separatedBy: "func createEvent(from draft: NewEventDraft)").dropFirst().first?
                .components(separatedBy: "func deleteEvent").first
        )
        let selection = try XCTUnwrap(
            createBody.range(of: "selectDate(CalendarDate(date: draft.startDate, calendar: calendar))")
        )
        let reload = try XCTUnwrap(createBody.range(of: "reloadCurrentEvents()"))

        XCTAssertLessThan(
            selection.lowerBound,
            reload.lowerBound,
            "The target month must be selected before the post-create refetch range is computed"
        )
    }
}

@MainActor
final class EventFetchCoordinatorTests: XCTestCase {
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
