import EventKit
import XCTest
@testable import equinox

final class CalendarAccessMappingTests: XCTestCase {
    func testCalendarAccessStatusFromWriteOnlyIsDenied() {
        XCTAssertEqual(CalendarAccessStatus.from(EKAuthorizationStatus.writeOnly), .denied)
    }

    func testGuiMappingForFullAccess() {
        let kind = CalendarAccessMapping.AccessKind.fullAccess
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

    func testAccessKindMapsEventKitStatuses() {
        XCTAssertEqual(CalendarAccessMapping.accessKind(for: EKAuthorizationStatus.fullAccess), .fullAccess)
        XCTAssertEqual(CalendarAccessMapping.accessKind(for: EKAuthorizationStatus.denied), .denied)
        XCTAssertEqual(CalendarAccessMapping.accessKind(for: EKAuthorizationStatus.notDetermined), .notDetermined)
        XCTAssertEqual(CalendarAccessMapping.accessKind(for: EKAuthorizationStatus.restricted), .restricted)
        XCTAssertEqual(CalendarAccessMapping.accessKind(for: EKAuthorizationStatus.writeOnly), .writeOnly)
    }
}
