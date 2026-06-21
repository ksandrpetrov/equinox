import EventKit
import XCTest
@testable import equinox

final class CalendarAccessMappingTests: XCTestCase {
    func testBridgeLabelForAccessKind() {
        XCTAssertEqual(CalendarAccessMapping.bridgeLabel(for: CalendarAccessMapping.AccessKind.fullAccess), "full_access")
        XCTAssertEqual(CalendarAccessMapping.bridgeLabel(for: CalendarAccessMapping.AccessKind.writeOnly), "write_only")
        XCTAssertEqual(CalendarAccessMapping.bridgeLabel(for: CalendarAccessMapping.AccessKind.notDetermined), "not_determined")
        XCTAssertEqual(CalendarAccessMapping.bridgeLabel(for: CalendarAccessMapping.AccessKind.restricted), "restricted")
        XCTAssertEqual(CalendarAccessMapping.bridgeLabel(for: CalendarAccessMapping.AccessKind.denied), "denied")
        XCTAssertEqual(CalendarAccessMapping.bridgeLabel(for: CalendarAccessMapping.AccessKind.unknown), "unknown")
    }

    func testAccessKindMapsLegacyAuthorizedToFullAccess() {
        XCTAssertEqual(CalendarAccessMapping.accessKind(for: EKAuthorizationStatus.authorized), .fullAccess)
        XCTAssertEqual(CalendarAccessMapping.accessKind(for: EKAuthorizationStatus.fullAccess), .fullAccess)
    }

    func testCalendarAccessStatusFromWriteOnlyIsDenied() {
        XCTAssertEqual(CalendarAccessStatus.from(EKAuthorizationStatus.writeOnly), .denied)
    }

    func testGuiAndBridgeMappingStayAlignedForFullAccess() {
        let kind = CalendarAccessMapping.AccessKind.fullAccess
        XCTAssertEqual(CalendarAccessMapping.bridgeLabel(for: kind), "full_access")
        XCTAssertEqual(CalendarAccessStatus.from(EKAuthorizationStatus.fullAccess), .authorized)
    }
}
