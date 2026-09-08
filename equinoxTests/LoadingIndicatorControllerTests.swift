import XCTest
@testable import equinox

@MainActor
final class LoadingIndicatorControllerTests: XCTestCase {
    func testFastFetchDoesNotFlashIndicator() async {
        let controller = LoadingIndicatorController()
        controller.beginFetch()
        controller.endFetch()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(controller.shouldShowLoadingIndicator)
    }

    func testSlowFetchShowsIndicatorAfterDelay() async {
        let controller = LoadingIndicatorController()
        controller.beginFetch()
        try? await Task.sleep(nanoseconds: 180_000_000)
        XCTAssertTrue(controller.shouldShowLoadingIndicator)
        controller.endFetch()
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertFalse(controller.shouldShowLoadingIndicator)
    }

    func testNestedFetchKeepsIndicatorVisibleUntilLastEnds() async {
        let controller = LoadingIndicatorController()
        controller.beginFetch()
        try? await Task.sleep(nanoseconds: 180_000_000)
        controller.beginFetch()
        controller.endFetch()
        XCTAssertTrue(controller.shouldShowLoadingIndicator)
        controller.endFetch()
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertFalse(controller.shouldShowLoadingIndicator)
    }

    func testNewFetchCancelsPendingShowTask() async {
        let controller = LoadingIndicatorController()
        controller.beginFetch()
        controller.beginFetch()
        controller.endFetch()
        controller.endFetch()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(controller.shouldShowLoadingIndicator)
    }

    func testNotifiesOnUpdate() {
        let controller = LoadingIndicatorController()
        var updates: [(Bool, Bool)] = []
        controller.onUpdate = { shouldShow, isFetching in
            updates.append((shouldShow, isFetching))
        }
        controller.beginFetch()
        XCTAssertEqual(updates.last?.1, true)
        controller.endFetch()
        XCTAssertEqual(updates.last?.1, false)
    }
}

@MainActor
final class PeriodicRefreshSchedulerTests: XCTestCase {
    func testStoppedSchedulerIgnoresAlreadyQueuedTick() {
        var callbacks: [@MainActor () -> Void] = []
        var ticks = 0
        let scheduler = PeriodicRefreshScheduler(schedule: { _, callback in
            callbacks.append(callback)
            return Timer(timeInterval: 60, repeats: false) { _ in }
        }, onTick: { ticks += 1 })
        scheduler.start()
        scheduler.start()
        XCTAssertEqual(callbacks.count, 1)
        scheduler.stop()
        callbacks[0]()
        XCTAssertEqual(ticks, 0)
        XCTAssertEqual(callbacks.count, 1)
        scheduler.start()
        callbacks[0]()
        XCTAssertEqual(ticks, 0, "A tick from the previous run must not affect the restarted timer")
        callbacks[1]()
        XCTAssertEqual(ticks, 1)
        XCTAssertEqual(callbacks.count, 3)
        scheduler.stop()
    }

    func testStoppingInsideTickDoesNotScheduleAnotherTimer() {
        var callbacks: [@MainActor () -> Void] = []
        var scheduler: PeriodicRefreshScheduler?
        scheduler = PeriodicRefreshScheduler(schedule: { _, callback in
            callbacks.append(callback)
            return Timer(timeInterval: 60, repeats: false) { _ in }
        }, onTick: { scheduler?.stop() })
        scheduler?.start()
        callbacks[0]()
        XCTAssertEqual(callbacks.count, 1)
        scheduler = nil
    }
}
