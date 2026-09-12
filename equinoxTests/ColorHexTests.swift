import XCTest
@testable import EquinoxKit

final class ColorHexTests: XCTestCase {
    func testNonFiniteComponentsCannotTrapDuringIntegerConversion() {
        XCTAssertEqual(ColorHex.rgbaToHex(red: .nan, green: .infinity, blue: -.infinity), "#00FF00")
    }
    func testRgbaToHexFormatsSRGB() {
        XCTAssertEqual(ColorHex.rgbaToHex(red: 1, green: 0.5, blue: 0), "#FF8000")
    }

    func testHexFromCGColor() {
        let color = CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [0, 0, 1, 1]
        )!
        XCTAssertEqual(ColorHex.hex(from: color), "#0000FF")
    }

    func testGrayscaleColorPreservesAlphaAndUsesEqualChannels() throws {
        let color = CGColor(gray: 0.25, alpha: 0.4)
        let rgba = try XCTUnwrap(ColorHex.cgColorComponents(color))

        XCTAssertEqual(rgba.red, 0.25, accuracy: 0.001)
        XCTAssertEqual(rgba.green, 0.25, accuracy: 0.001)
        XCTAssertEqual(rgba.blue, 0.25, accuracy: 0.001)
        XCTAssertEqual(rgba.alpha, 0.4, accuracy: 0.001)
    }

    func testRgbaToHexClampsExtendedComponents() {
        XCTAssertEqual(ColorHex.rgbaToHex(red: -0.2, green: 1.4, blue: 0.5), "#00FF80")
    }

    func testEventKitCalendarMappingUsesColorHex() {
        let color = CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [1, 0, 0, 1]
        )!
        XCTAssertEqual(EventKitCalendarMapping.colorHex(color), "#FF0000")
    }

    func testGenericRGBIsConvertedToSRGB() throws {
        let generic = CGColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        let converted = try XCTUnwrap(generic.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent,
            options: nil
        ))
        let expected = try XCTUnwrap(converted.components)
        let actual = try XCTUnwrap(ColorHex.cgColorComponents(generic))

        XCTAssertEqual(actual.red, expected[0], accuracy: 0.001)
        XCTAssertEqual(actual.green, expected[1], accuracy: 0.001)
        XCTAssertEqual(actual.blue, expected[2], accuracy: 0.001)
        XCTAssertEqual(actual.alpha, expected[3], accuracy: 0.001)
    }
}
