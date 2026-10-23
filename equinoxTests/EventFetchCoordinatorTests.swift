import XCTest
@testable import EquinoxKit

@MainActor
final class EventFetchCoordinatorTests: XCTestCase {
    func testCancelledCallerDoesNotCancelSharedRefreshOrLeaveLoadingActive() async {
        let store = StubCalendarEventStore()
        let coordinator = EventFetchCoordinator(calendarStore: store)
        let day = CalendarDate(year: 2026, monthIndex: 9, day: 2)
        let suspended = expectation(description: "Active fetch suspended")
        var release: CheckedContinuation<Void, Never>?
        var requests = 0
        store.onFetch = { _, _, _ in
            requests += 1
            if requests == 1 {
                await withCheckedContinuation { release = $0; suspended.fulfill() }
            }
            return true
        }
        var loading = false
        var snapshots = 0
        coordinator.onPresentationUpdate = { _, fetching in loading = fetching }
        coordinator.onSyncComplete = { _ in snapshots += 1 }
        let cancelled = Task { await coordinator.fetch(range: (day, day)) }
        await fulfillment(of: [suspended], timeout: 2)
        cancelled.cancel()
        let pendingStarted = expectation(description: "Refresh enqueued")
        let refresh = Task {
            pendingStarted.fulfill()
            return await coordinator.fetch(range: (day, day.addingDays(7)), refetch: true)
        }
        await fulfillment(of: [pendingStarted], timeout: 2)
        XCTAssertTrue(loading)
        release?.resume()
        let refreshSucceeded = await refresh.value
        _ = await cancelled.value
        XCTAssertTrue(refreshSucceeded)
        XCTAssertFalse(loading)
        XCTAssertEqual(requests, 2)
        XCTAssertEqual(snapshots, 2)
        XCTAssertEqual(store.refetchedRanges.last?.last, day.addingDays(7))
    }

    func testWorkEnqueuedDuringSnapshotSynchronizationIsDrained() async {
        let store = StubCalendarEventStore()
        let coordinator = EventFetchCoordinator(calendarStore: store)
        let day = CalendarDate.minimumSupported
        let synchronized = expectation(description: "Both snapshots synchronized")
        synchronized.expectedFulfillmentCount = 2
        var syncs = 0
        coordinator.onSyncComplete = { _ in
            syncs += 1
            if syncs == 1 { coordinator.scheduleFetch(range: (day, day.addingDays(5)), refetch: true) }
            synchronized.fulfill()
        }
        let result = await coordinator.fetch(range: (day, day))
        XCTAssertTrue(result)
        await fulfillment(of: [synchronized], timeout: 2)
        XCTAssertEqual(store.fetchedRanges.count, 1)
        XCTAssertEqual(store.refetchedRanges.count, 1)
        coordinator.onSyncComplete = nil
    }

    func testRapidNavigationFetchesOnlyFinalRange() async {
        let store = StubCalendarEventStore()
        let delay = ManualNavigationDelay(requests: 24)
        defer { delay.resumeAll() }
        let coordinator = EventFetchCoordinator(calendarStore: store, navigationDelay: delay.wait)
        let fetched = expectation(description: "Final navigation range fetched")
        coordinator.onSyncComplete = { _ in fetched.fulfill() }
        let start = CalendarDate(year: 2026, monthIndex: 0, day: 1)
        for month in 1...24 {
            let first = start.addingMonths(month)
            coordinator.scheduleNavigationFetch(range: (first, first.addingDays(41)))
        }
        XCTAssertTrue(store.fetchedRanges.isEmpty)
        await fulfillment(of: [delay.suspended], timeout: 2)
        delay.resumeAll()
        await fulfillment(of: [delay.completed, fetched], timeout: 2)
        XCTAssertEqual(store.fetchedRanges.count, 1)
        XCTAssertEqual(store.fetchedRanges.first?.first, start.addingMonths(24))
    }

    func testExplicitRefreshSupersedesDelayedNavigation() async throws {
        let store = StubCalendarEventStore()
        let delay = ManualNavigationDelay()
        defer { delay.resumeAll() }
        let coordinator = EventFetchCoordinator(calendarStore: store, navigationDelay: delay.wait)
        let day = CalendarDate(year: 2026, monthIndex: 0, day: 1)
        coordinator.scheduleNavigationFetch(range: (day, day.addingDays(30)))
        await fulfillment(of: [delay.suspended], timeout: 2)
        let succeeded = await coordinator.fetch(range: (day, day.addingDays(60)), refetch: true)
        XCTAssertTrue(succeeded)
        delay.resumeAll()
        await fulfillment(of: [delay.completed], timeout: 2)
        XCTAssertTrue(store.fetchedRanges.isEmpty)
        XCTAssertEqual(store.refetchedRanges.count, 1)
        XCTAssertEqual(store.refetchedRanges.first?.last, day.addingDays(60))
    }

    func testAccessCanBePreparedAgainAfterDenial() async {
        let store = StubCalendarEventStore()
        store.accessGranted = false
        let coordinator = EventFetchCoordinator(calendarStore: store)
        let day = CalendarDate.minimumSupported
        let denied = await coordinator.fetch(range: (day, day), refetch: true)
        XCTAssertFalse(denied)
        XCTAssertTrue(store.refetchedRanges.isEmpty)
        XCTAssertTrue(store.fetchedRanges.isEmpty)

        store.accessGranted = true
        let granted = await coordinator.fetch(range: (day, day), refetch: true, preparesCalendarAccess: true)
        XCTAssertTrue(granted)
        XCTAssertEqual(store.accessRequestCount, 2)
        XCTAssertEqual(store.refetchedRanges.count, 1)
    }

    func testFailedFetchFinishesLoadingAndRetrySynchronizesSuccess() async {
        let store = StubCalendarEventStore()
        store.fetchResult = false
        let coordinator = EventFetchCoordinator(calendarStore: store)
        let day = CalendarDate.minimumSupported
        var results: [Bool] = []
        var isFetching = false
        coordinator.onSyncComplete = { results.append($0) }
        coordinator.onPresentationUpdate = { _, fetching in isFetching = fetching }

        let failed = await coordinator.fetch(range: (day, day))
        XCTAssertFalse(failed)
        XCTAssertFalse(isFetching)
        XCTAssertEqual(store.fetchedRanges.count, 1)

        let retried = await coordinator.fetch(range: (day, day), refetch: true)
        XCTAssertTrue(retried)
        XCTAssertFalse(isFetching)
        XCTAssertEqual(results, [false, true])
        XCTAssertEqual(store.refetchedRanges.count, 1)
    }

    func testSupersededPendingRequestDoesNotReportSuccessfulFetch() async {
        for distant in [CalendarDate.minimumSupported, CalendarDate.maximumSupported] {
            let day = CalendarDate(year: 2026, monthIndex: 0, day: 1)
            var release: CheckedContinuation<Void, Never>?
            var fetchCalls = 0
            let firstSuspended = expectation(description: "First fetch suspended")
            let activeCompleted = expectation(description: "Active request completed")
            let pendingCompleted = expectation(description: "Superseded request completed before active fetch")
            let secondFetched = expectation(description: "Second fetch completed")
            let coordinator = EventFetchCoordinator(
                requestCalendarAccess: { true },
                fetchEvents: { _, _ in
                    fetchCalls += 1
                    if fetchCalls == 1 {
                        await withCheckedContinuation { release = $0; firstSuspended.fulfill() }
                    }
                    if fetchCalls == 2 { secondFetched.fulfill() }
                    return true
                },
                refetchEvents: { _, _ in true }
            )
            var activeSucceeded: Bool?
            let active = Task {
                activeSucceeded = await coordinator.fetch(range: (day, day))
                activeCompleted.fulfill()
            }
            await fulfillment(of: [firstSuspended], timeout: 2)
            let pendingStarted = expectation(description: "Pending request enqueued")
            var supersededSucceeded: Bool?
            let pending = Task {
                pendingStarted.fulfill()
                supersededSucceeded = await coordinator.fetch(range: (day.addingDays(1), day.addingDays(2)))
                pendingCompleted.fulfill()
            }
            defer {
                release?.resume()
                active.cancel()
                pending.cancel()
            }
            await fulfillment(of: [pendingStarted], timeout: 2)
            coordinator.scheduleFetch(range: (distant, distant))
            await fulfillment(of: [pendingCompleted], timeout: 2)
            XCTAssertEqual(supersededSucceeded, false)
            release?.resume()
            release = nil
            await fulfillment(of: [activeCompleted, secondFetched], timeout: 2)
            XCTAssertEqual(activeSucceeded, true)
        }
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
        var fetchCalls = 0
        let firstSuspended = expectation(description: "First fetch suspended")
        let allSynced = expectation(description: "Both snapshots synchronized")
        let allCompleted = expectation(description: "All callers receive the fetch result")
        allCompleted.expectedFulfillmentCount = 3

        let coordinator = EventFetchCoordinator(
            requestCalendarAccess: {
                operations.append("access")
                return true
            },
            fetchEvents: { first, last in
                fetchCalls += 1
                operations.append("fetch:\(first.julian)-\(last.julian)")
                if fetchCalls == 1 {
                    await withCheckedContinuation { continuation in
                        releaseFirstFetch = continuation
                        firstSuspended.fulfill()
                    }
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
            if syncedSnapshots.count == 2 { allSynced.fulfill() }
        }

        var results: [Bool?] = [nil, nil, nil]
        let firstTask = Task {
            results[0] = await coordinator.fetch(range: firstRange)
            allCompleted.fulfill()
        }
        await fulfillment(of: [firstSuspended], timeout: 2)

        let secondStarted = expectation(description: "Second range enqueued")
        let secondTask = Task {
            secondStarted.fulfill()
            results[1] = await coordinator.fetch(range: secondRange)
            allCompleted.fulfill()
        }
        await fulfillment(of: [secondStarted], timeout: 2)
        let thirdStarted = expectation(description: "Third range enqueued")
        let thirdTask = Task {
            thirdStarted.fulfill()
            results[2] = await coordinator.fetch(range: thirdRange, refetch: true, preparesCalendarAccess: true)
            allCompleted.fulfill()
        }
        defer {
            releaseFirstFetch?.resume()
            firstTask.cancel()
            secondTask.cancel()
            thirdTask.cancel()
        }
        await fulfillment(of: [thirdStarted], timeout: 2)

        XCTAssertEqual(
            operations,
            ["access", "fetch:\(firstRange.first.julian)-\(firstRange.last.julian)"],
            "pending work must not start while the first fetch is suspended"
        )

        releaseFirstFetch?.resume()
        releaseFirstFetch = nil
        await fulfillment(of: [allSynced, allCompleted], timeout: 2)
        XCTAssertEqual(results, [true, true, true])

        XCTAssertEqual(
            operations,
            ["access", "fetch:\(firstRange.first.julian)-\(firstRange.last.julian)",
             "access", "refetch:\(thirdRange.first.julian)-\(thirdRange.last.julian)"],
            "Pending ranges must be unioned and upgraded to refetch and access preparation"
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

    func testInvalidRangeDoesNotRequestAccessOrFetch() async {
        var operations = 0
        let coordinator = EventFetchCoordinator(
            requestCalendarAccess: { operations += 1; return true },
            fetchEvents: { _, _ in operations += 1; return true },
            refetchEvents: { _, _ in operations += 1; return true }
        )
        let day = CalendarDate.minimumSupported
        let ranges = [(day.addingDays(1), day), (day.addingDays(-1), day)]
        let completed = expectation(description: "Invalid requests return without fetching")
        completed.expectedFulfillmentCount = ranges.count
        var results = [Bool?](repeating: nil, count: ranges.count)
        let tasks = ranges.enumerated().map { index, range in
            Task {
                results[index] = await coordinator.fetch(range: range)
                completed.fulfill()
            }
        }
        defer { tasks.forEach { $0.cancel() } }
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(results, [false, false])
        XCTAssertEqual(operations, 0)
    }
}
