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
