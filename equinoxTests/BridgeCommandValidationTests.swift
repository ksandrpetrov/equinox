import XCTest
@testable import equinox

final class BridgeCommandValidationTests: XCTestCase {
    func testEndIsAfterStartRejectsEqualDates() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertFalse(BridgeCommandValidation.endIsAfterStart(start: date, end: date))
    }

    func testEndIsAfterStartAcceptsLaterEnd() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = start.addingTimeInterval(60)
        XCTAssertTrue(BridgeCommandValidation.endIsAfterStart(start: start, end: end))
    }

    func testBridgeUpdateRequiresAtLeastOneMutableField() {
        XCTAssertFalse(BridgeCommandValidation.bridgeUpdateHasMutableField(
            title: nil,
            startDate: nil,
            endDate: nil,
            allDay: nil,
            location: nil,
            notes: nil,
            url: nil,
            calendarId: nil
        ))
        XCTAssertTrue(BridgeCommandValidation.bridgeUpdateHasMutableField(
            title: "Updated",
            startDate: nil,
            endDate: nil,
            allDay: nil,
            location: nil,
            notes: nil,
            url: nil,
            calendarId: nil
        ))
    }
}
