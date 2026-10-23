import EventKit
import XCTest
@testable import EquinoxKit

final class EventParticipationTests: XCTestCase {
    func testDomainStatusesMatchEventKitRatherThanTheirOwnRawValues() {
        let cases: [(EKParticipantStatus, EventParticipationStatus)] = [
            (.unknown, .unknown), (.pending, .pending), (.accepted, .accepted),
            (.declined, .declined), (.tentative, .tentative), (.delegated, .delegated),
            (.completed, .completed), (.inProcess, .inProcess)
        ]
        for (eventKit, expected) in cases {
            XCTAssertEqual(EventParticipationStatus.fromEventKitRawValue(eventKit.rawValue), expected)
            XCTAssertEqual(EventParticipationMapping.status(eventKitRawValue: eventKit.rawValue), expected)
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
