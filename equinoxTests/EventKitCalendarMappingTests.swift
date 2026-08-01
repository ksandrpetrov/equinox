import XCTest
@testable import equinox

final class EventKitCalendarMappingTests: XCTestCase {
    func testColorHexFormatsSRGB() {
        let color = CGColor(red: 1, green: 0.5, blue: 0, alpha: 1)
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
