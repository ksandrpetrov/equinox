import XCTest
@testable import EquinoxKit

@MainActor
final class EventFetchCoordinatorTests: XCTestCase {
    func testSupersededPendingRequestDoesNotReportSuccessfulFetch() async {
        let day = CalendarDate(year: 2026, monthIndex: 0, day: 1)
        var release: CheckedContinuation<Void, Never>?
        var fetchCalls = 0
        let firstSuspended = expectation(description: "First fetch suspended")
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
        let active = Task { await coordinator.fetch(range: (day, day)) }
        await fulfillment(of: [firstSuspended], timeout: 2)
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
        await fulfillment(of: [secondFetched], timeout: 2)
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
        let firstSuspended = expectation(description: "First fetch suspended")
        let allSynced = expectation(description: "Both snapshots synchronized")

        let coordinator = EventFetchCoordinator(
            requestCalendarAccess: {
                operations.append("access")
                return true
            },
            fetchEvents: { first, last in
                operations.append("fetch:\(first.julian)-\(last.julian)")
                await withCheckedContinuation { continuation in
                    releaseFirstFetch = continuation
                    firstSuspended.fulfill()
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

        let firstTask = Task {
            await coordinator.fetch(range: firstRange)
        }
        await fulfillment(of: [firstSuspended], timeout: 2)

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
        await fulfillment(of: [allSynced], timeout: 2)

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

    func testInvalidRangeDoesNotRequestAccessOrFetch() async {
        var operations = 0
        let coordinator = EventFetchCoordinator(
            requestCalendarAccess: { operations += 1; return true },
            fetchEvents: { _, _ in operations += 1; return true },
            refetchEvents: { _, _ in operations += 1; return true }
        )
        let day = CalendarDate.minimumSupported
        for range in [(day.addingDays(1), day), (day.addingDays(-1), day)] {
            let success = await coordinator.fetch(range: range)
            XCTAssertFalse(success)
        }
        XCTAssertEqual(operations, 0)
    }
}
