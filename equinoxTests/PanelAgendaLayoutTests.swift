import XCTest
@testable import equinox

final class PanelAgendaLayoutTests: XCTestCase {
    func testMaxHeightUsesDesignTokensAndMetrics() {
        let small = SizeMetrics.metrics(for: .small)
        let large = SizeMetrics.metrics(for: .large)
        let screenHeight: CGFloat = 900

        let smallHeight = PanelAgendaLayout.maxHeight(
            metrics: small,
            calendarRowCount: 6,
            screenVisibleHeight: screenHeight
        )
        let largeHeight = PanelAgendaLayout.maxHeight(
            metrics: large,
            calendarRowCount: 6,
            screenVisibleHeight: screenHeight
        )

        XCTAssertGreaterThanOrEqual(smallHeight, 0)
        XCTAssertLessThanOrEqual(smallHeight, EquinoxDesign.panelAgendaMaxHeight)
        XCTAssertGreaterThan(smallHeight, largeHeight)
    }

    func testMaxHeightDoesNotOverflowSmallScreens() {
        let metrics = SizeMetrics.metrics(for: .medium)
        let height = PanelAgendaLayout.maxHeight(
            metrics: metrics,
            calendarRowCount: 8,
            screenVisibleHeight: 200
        )
        XCTAssertEqual(height, 0)
    }

    @MainActor
    func testChangingScreenHeightInvalidatesPanelSizeOnce() {
        let layout = PanelLayoutMetrics()
        var invalidationCount = 0
        layout.onPanelSizeInvalidated = { invalidationCount += 1 }

        layout.panelAgendaMaxHeight = 180
        layout.panelAgendaMaxHeight = 180

        XCTAssertEqual(invalidationCount, 1)
    }
}
