import XCTest
@testable import equinox

final class EventParticipationTests: XCTestCase {
    func testFromEventKitRawValueRoundTrip() {
        for status in EventParticipationStatus.allCases {
            XCTAssertEqual(
                EventParticipationStatus.fromEventKitRawValue(status.rawValue),
                status
            )
        }
    }

    func testNeedsResponse() {
        XCTAssertTrue(EventParticipationStatus.pending.needsResponse)
        XCTAssertTrue(EventParticipationStatus.unknown.needsResponse)
        XCTAssertFalse(EventParticipationStatus.accepted.needsResponse)
        XCTAssertFalse(EventParticipationStatus.tentative.needsResponse)
        XCTAssertFalse(EventParticipationStatus.declined.needsResponse)
    }

    func testStatusWithoutAttendeesReturnsNil() {
        XCTAssertNil(EventParticipationMapping.status(hasAttendees: false, eventKitRawValue: 2))
    }

    func testStatusWithAttendeesAndNilRawValueIsUnknown() {
        XCTAssertEqual(
            EventParticipationMapping.status(hasAttendees: true, eventKitRawValue: nil),
            .unknown
        )
    }

    func testStatusWithAttendeesMapsRawValue() {
        XCTAssertEqual(
            EventParticipationMapping.status(hasAttendees: true, eventKitRawValue: 4),
            .tentative
        )
    }

    func testUnknownRawValueFallsBackToUnknown() {
        XCTAssertEqual(
            EventParticipationMapping.status(hasAttendees: true, eventKitRawValue: 99),
            .unknown
        )
    }

    func testIsDeclinedParticipation() {
        XCTAssertTrue(EventParticipationMapping.isDeclinedParticipation(hasAttendees: true, eventKitRawValue: 3))
        XCTAssertFalse(EventParticipationMapping.isDeclinedParticipation(hasAttendees: true, eventKitRawValue: 2))
        XCTAssertFalse(EventParticipationMapping.isDeclinedParticipation(hasAttendees: false, eventKitRawValue: 3))
        XCTAssertFalse(EventParticipationMapping.isDeclinedParticipation(hasAttendees: true, eventKitRawValue: nil))
    }

    func testBridgeStatusNameMapsAllStatuses() {
        XCTAssertNil(EventParticipationMapping.bridgeStatusName(hasAttendees: false, eventKitRawValue: 2))
        XCTAssertEqual(EventParticipationMapping.bridgeStatusName(hasAttendees: true, eventKitRawValue: nil), "unknown")
        XCTAssertEqual(EventParticipationMapping.bridgeStatusName(hasAttendees: true, eventKitRawValue: 1), "pending")
        XCTAssertEqual(EventParticipationMapping.bridgeStatusName(hasAttendees: true, eventKitRawValue: 2), "accepted")
        XCTAssertEqual(EventParticipationMapping.bridgeStatusName(hasAttendees: true, eventKitRawValue: 3), "declined")
        XCTAssertEqual(EventParticipationMapping.bridgeStatusName(hasAttendees: true, eventKitRawValue: 4), "tentative")
        XCTAssertEqual(EventParticipationMapping.bridgeStatusName(hasAttendees: true, eventKitRawValue: 99), "unknown")
    }
}
