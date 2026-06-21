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
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: kind), .authorized)
        XCTAssertEqual(CalendarAccessStatus.from(EKAuthorizationStatus.fullAccess), .authorized)
    }

    func testGuiStatusForAllAccessKinds() {
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.AccessKind.fullAccess), .authorized)
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.AccessKind.writeOnly), .denied)
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.AccessKind.denied), .denied)
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.AccessKind.notDetermined), .notDetermined)
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.AccessKind.restricted), .restricted)
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.AccessKind.unknown), .notDetermined)
    }

    func testBridgeLabelMapsEventKitStatuses() {
        XCTAssertEqual(CalendarAccessMapping.bridgeLabel(for: EKAuthorizationStatus.denied), "denied")
        XCTAssertEqual(CalendarAccessMapping.bridgeLabel(for: EKAuthorizationStatus.notDetermined), "not_determined")
        XCTAssertEqual(CalendarAccessMapping.bridgeLabel(for: EKAuthorizationStatus.restricted), "restricted")
        XCTAssertEqual(CalendarAccessMapping.bridgeLabel(for: EKAuthorizationStatus.writeOnly), "write_only")
    }

    func testAccessKindMapsEventKitStatuses() {
        XCTAssertEqual(CalendarAccessMapping.accessKind(for: EKAuthorizationStatus.denied), .denied)
        XCTAssertEqual(CalendarAccessMapping.accessKind(for: EKAuthorizationStatus.notDetermined), .notDetermined)
        XCTAssertEqual(CalendarAccessMapping.accessKind(for: EKAuthorizationStatus.restricted), .restricted)
        XCTAssertEqual(CalendarAccessMapping.accessKind(for: EKAuthorizationStatus.writeOnly), .writeOnly)
    }
}
