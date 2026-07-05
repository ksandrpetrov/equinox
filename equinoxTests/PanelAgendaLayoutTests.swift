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

        XCTAssertGreaterThanOrEqual(smallHeight, PanelAgendaLayout.agendaMaxHeightFloor)
        XCTAssertLessThanOrEqual(smallHeight, EquinoxDesign.panelAgendaMaxHeight)
        XCTAssertGreaterThan(smallHeight, largeHeight)
    }

    func testMaxHeightRespectsFloorOnSmallScreens() {
        let metrics = SizeMetrics.metrics(for: .medium)
        let height = PanelAgendaLayout.maxHeight(
            metrics: metrics,
            calendarRowCount: 8,
            screenVisibleHeight: 200
        )
        XCTAssertEqual(height, PanelAgendaLayout.agendaMaxHeightFloor)
    }
}
