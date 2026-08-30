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

    func testAgendaIsEitherUsableOrHiddenAcrossSupportedLayouts() {
        for preference in SizePreference.allCases {
            for rowCount in 6...10 {
                for screenHeight: CGFloat in [480, 600, 900, 1_440] {
                    let height = PanelAgendaLayout.maxHeight(
                        metrics: SizeMetrics.metrics(for: preference),
                        calendarRowCount: rowCount,
                        screenVisibleHeight: screenHeight
                    )

                    XCTAssertTrue(
                        height == 0 || height >= AgendaLayout.minHeight,
                        "Agenda height \(height) is unusable for \(preference), \(rowCount) rows, \(screenHeight) pt"
                    )
                    XCTAssertLessThanOrEqual(height, EquinoxDesign.panelAgendaMaxHeight)
                }
            }
        }
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
