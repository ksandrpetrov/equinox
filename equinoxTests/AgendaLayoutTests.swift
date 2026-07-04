import XCTest
@testable import equinox

final class AgendaLayoutTests: XCTestCase {
    func testAgendaHeightUsesRatioAgainstDefault() {
        let height = AgendaLayout.agendaHeight(maxHeight: 300, heightRatio: 0.35)
        XCTAssertEqual(height, 300)
    }

    func testAgendaHeightRespectsMinimum() {
        let height = AgendaLayout.agendaHeight(maxHeight: 80, heightRatio: 0.15)
        XCTAssertEqual(height, AgendaLayout.minHeight)
    }
}
