import XCTest
@testable import equinox

final class ColorHexTests: XCTestCase {
    func testRgbaToHexFormatsSRGB() {
        XCTAssertEqual(ColorHex.rgbaToHex(red: 1, green: 0.5, blue: 0), "#FF8000")
    }

    func testHexFromCGColor() {
        let color = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        XCTAssertEqual(ColorHex.hex(from: color), "#0000FF")
    }

    func testHexOrGrayUsesFallbackForNil() {
        XCTAssertEqual(ColorHex.hexOrGray(nil), "#808080")
    }

    func testEventKitCalendarMappingUsesColorHex() {
        let color = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        XCTAssertEqual(EventKitCalendarMapping.colorHex(color), "#FF0000")
        XCTAssertEqual(EventKitCalendarMapping.colorHexOrGray(color), "#FF0000")
    }
}
