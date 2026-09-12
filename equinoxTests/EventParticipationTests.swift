import XCTest
@testable import EquinoxKit

final class EventParticipationTests: XCTestCase {
    func testFromEventKitRawValueRoundTrip() {
        for status in EventParticipationStatus.allCases {
            XCTAssertEqual(
                EventParticipationStatus.fromEventKitRawValue(status.rawValue),
                status
            )
        }
    }

    func testMissingCurrentUserStatusReturnsNil() {
        XCTAssertNil(EventParticipationMapping.status(eventKitRawValue: nil))
    }

    func testStatusWithAttendeesMapsRawValue() {
        XCTAssertEqual(
            EventParticipationMapping.status(eventKitRawValue: 4),
            .tentative
        )
    }

    func testUnknownRawValueFallsBackToUnknown() {
        XCTAssertEqual(
            EventParticipationMapping.status(eventKitRawValue: 99),
            .unknown
        )
    }

    func testIsDeclinedParticipation() {
        XCTAssertTrue(EventParticipationMapping.isDeclinedParticipation(eventKitRawValue: 3))
        XCTAssertFalse(EventParticipationMapping.isDeclinedParticipation(eventKitRawValue: 2))
        XCTAssertFalse(EventParticipationMapping.isDeclinedParticipation(eventKitRawValue: nil))
    }
}
