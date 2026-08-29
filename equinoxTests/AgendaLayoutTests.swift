import XCTest
@testable import equinox

final class AgendaLayoutTests: XCTestCase {
    func testMinimumRatioUsesMinimumHeight() {
        let height = AgendaLayout.agendaHeight(maxHeight: 400, heightRatio: 0.15)
        XCTAssertEqual(height, AgendaLayout.minHeight)
    }

    func testMaximumRatioUsesMaximumHeight() {
        let height = AgendaLayout.agendaHeight(maxHeight: 400, heightRatio: 0.65)
        XCTAssertEqual(height, 400)
    }

    func testDefaultRatioUsesFortyPercentOfAvailableRange() {
        let maxHeight: CGFloat = 400
        let expected = AgendaLayout.minHeight + (maxHeight - AgendaLayout.minHeight) * 0.4

        let height = AgendaLayout.agendaHeight(
            maxHeight: maxHeight,
            heightRatio: AgendaLayout.defaultHeightRatio
        )

        XCTAssertEqual(height, expected, accuracy: 0.000_1)
    }

    func testBudgetBelowMinimumNeverExceedsMaximumHeight() {
        let height = AgendaLayout.agendaHeight(maxHeight: 80, heightRatio: 0.65)
        XCTAssertEqual(height, 80)
    }

    func testNonPositiveBudgetProducesZeroHeight() {
        XCTAssertEqual(AgendaLayout.agendaHeight(maxHeight: 0, heightRatio: 0.35), 0)
        XCTAssertEqual(AgendaLayout.agendaHeight(maxHeight: -20, heightRatio: 0.35), 0)
    }
}
