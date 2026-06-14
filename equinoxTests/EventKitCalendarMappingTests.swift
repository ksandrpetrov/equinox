import AppKit
import EventKit
import XCTest
@testable import equinox

final class EventKitCalendarMappingTests: XCTestCase {
    func testColorHexFormatsSRGB() {
        let color = NSColor(red: 1, green: 0.5, blue: 0, alpha: 1)
        XCTAssertEqual(EventKitCalendarMapping.colorHex(color), "#FF8000")
    }

    func testColorHexOrGrayUsesFallbackForNil() {
        XCTAssertEqual(EventKitCalendarMapping.colorHexOrGray(nil), "#808080")
    }

    func testColorHexOrGrayUsesColorWhenPresent() {
        let color = NSColor(red: 0, green: 0, blue: 1, alpha: 1)
        XCTAssertEqual(EventKitCalendarMapping.colorHexOrGray(color), "#0000FF")
    }

    func testCalendarTypeLabels() {
        XCTAssertEqual(EventKitCalendarMapping.calendarTypeLabel(.local), "local")
        XCTAssertEqual(EventKitCalendarMapping.calendarTypeLabel(.calDAV), "caldav")
        XCTAssertEqual(EventKitCalendarMapping.calendarTypeLabel(.exchange), "exchange")
        XCTAssertEqual(EventKitCalendarMapping.calendarTypeLabel(.subscription), "subscription")
        XCTAssertEqual(EventKitCalendarMapping.calendarTypeLabel(.birthday), "birthday")
    }
}
