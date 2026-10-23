import EventKit
import XCTest
@testable import EquinoxKit

final class CalendarAccessMappingTests: XCTestCase {
    func testGuiStatusForAllAccessKinds() {
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.AccessKind.fullAccess), .authorized)
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.AccessKind.writeOnly), .denied)
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.AccessKind.denied), .denied)
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.AccessKind.notDetermined), .notDetermined)
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.AccessKind.restricted), .restricted)
        XCTAssertEqual(CalendarAccessMapping.guiStatus(for: CalendarAccessMapping.AccessKind.unknown), .notDetermined)
    }

    func testAccessKindMapsEventKitStatuses() {
        let cases: [(EKAuthorizationStatus, CalendarAccessMapping.AccessKind, CalendarAccessStatus)] = [
            (.fullAccess, .fullAccess, .authorized), (.denied, .denied, .denied),
            (.notDetermined, .notDetermined, .notDetermined), (.restricted, .restricted, .restricted),
            (.writeOnly, .writeOnly, .denied),
        ]
        for (status, kind, expected) in cases {
            XCTAssertEqual(CalendarAccessMapping.accessKind(for: status), kind, "\(status)")
            XCTAssertEqual(CalendarAccessStatus.from(status), expected, "\(status)")
        }
    }
}
