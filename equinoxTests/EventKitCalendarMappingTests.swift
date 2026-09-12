import XCTest
@testable import EquinoxKit

final class EventKitCalendarMappingTests: XCTestCase {
    func testColorHexFormatsSRGB() {
        let color = CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [1, 0.5, 0, 1]
        )!
        XCTAssertEqual(EventKitCalendarMapping.colorHex(color), "#FF8000")
    }

    func testCalendarTypeLabels() {
        XCTAssertEqual(EventKitCalendarMapping.calendarTypeLabel(.local), "local")
        XCTAssertEqual(EventKitCalendarMapping.calendarTypeLabel(.calDAV), "caldav")
        XCTAssertEqual(EventKitCalendarMapping.calendarTypeLabel(.exchange), "exchange")
        XCTAssertEqual(EventKitCalendarMapping.calendarTypeLabel(.subscription), "subscription")
        XCTAssertEqual(EventKitCalendarMapping.calendarTypeLabel(.birthday), "birthday")
    }
}
