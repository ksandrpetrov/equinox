import XCTest
@testable import EquinoxKit

@MainActor
final class LoadingIndicatorControllerTests: XCTestCase {
    func testFastFetchDoesNotFlashEvenIfCancelledCallbackArrives() {
        let clock = ManualSchedule()
        let controller = clock.controller()
        controller.beginFetch()
        controller.endFetch()
        clock.fireCancelledActions()
        clock.advance(by: 1)
        XCTAssertFalse(controller.shouldShowLoadingIndicator)
        XCTAssertFalse(controller.isFetchingEvents)
    }

    func testShowDeadlineAndMinimumVisibility() {
        let clock = ManualSchedule()
        let controller = clock.controller()
        controller.beginFetch()
        clock.advance(by: 0.149)
        XCTAssertFalse(controller.shouldShowLoadingIndicator)
        clock.advance(by: 0.002)
        XCTAssertTrue(controller.shouldShowLoadingIndicator)
        controller.endFetch()
        XCTAssertFalse(controller.isFetchingEvents)
        clock.advance(by: 0.199)
        XCTAssertTrue(controller.shouldShowLoadingIndicator)
        clock.advance(by: 0.002)
        XCTAssertFalse(controller.shouldShowLoadingIndicator)
    }

    func testOverlappingFetchDoesNotPostponeShowDeadline() {
        let clock = ManualSchedule()
        let controller = clock.controller()
        controller.beginFetch()
        clock.advance(by: 0.1)
        controller.beginFetch()
        clock.advance(by: 0.051)
        XCTAssertTrue(controller.shouldShowLoadingIndicator)
        controller.endFetch()
        clock.advance(by: 1)
        XCTAssertTrue(controller.shouldShowLoadingIndicator)
        XCTAssertTrue(controller.isFetchingEvents)
        controller.endFetch()
        XCTAssertFalse(controller.shouldShowLoadingIndicator)
    }

    func testNewFetchCancelsPendingHideWithoutFlicker() {
        let clock = ManualSchedule()
        let controller = clock.controller()
        controller.beginFetch()
        clock.advance(by: 0.15)
        controller.endFetch()
        controller.beginFetch()
        clock.fireCancelledActions()
        clock.advance(by: 1)
        XCTAssertTrue(controller.shouldShowLoadingIndicator)
        controller.endFetch()
        XCTAssertFalse(controller.shouldShowLoadingIndicator)
    }

    func testUnbalancedEndIsIgnoredAndCompletionNotifiesImmediately() {
        let clock = ManualSchedule()
        let controller = clock.controller()
        var updates: [(Bool, Bool)] = []
        controller.onUpdate = { updates.append(($0, $1)) }
        controller.endFetch()
        XCTAssertTrue(updates.isEmpty)
        controller.beginFetch()
        clock.advance(by: 0.15)
        controller.endFetch()
        XCTAssertEqual(updates.last?.0, true)
        XCTAssertEqual(updates.last?.1, false)
        clock.advance(by: 1)
        XCTAssertEqual(updates.last?.0, false)
    }

    func testPendingActionDoesNotRetainController() {
        let clock = ManualSchedule()
        var controller: LoadingIndicatorController? = clock.controller()
        weak var reference = controller
        controller?.beginFetch()
        controller = nil
        clock.advance(by: 1)
        XCTAssertNil(reference)
    }
}

@MainActor
private final class ManualSchedule {
    private final class Action {
        let deadline: TimeInterval
        let run: @MainActor () -> Void
        var cancelled = false
        init(deadline: TimeInterval, run: @escaping @MainActor () -> Void) {
            self.deadline = deadline
            self.run = run
        }
    }
    private var now: TimeInterval = 0
    private var actions: [Action] = []

    func controller() -> LoadingIndicatorController {
        LoadingIndicatorController(now: { self.now }, schedule: { delay, run in
            let action = Action(deadline: self.now + delay, run: run)
            self.actions.append(action)
            return { action.cancelled = true }
        })
    }

    func advance(by interval: TimeInterval) {
        now += interval
        let due = actions.filter { $0.deadline <= now }
        actions.removeAll { $0.deadline <= now }
        for action in due where !action.cancelled { action.run() }
    }

    func fireCancelledActions() {
        for action in actions where action.cancelled { action.run() }
    }
}
