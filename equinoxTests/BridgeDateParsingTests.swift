import XCTest
@testable import equinox

final class BridgeDateParsingTests: XCTestCase {
    func testParseInstantWithFractionalSeconds() {
        let date = BridgeDateParsing.parseInstant("2026-06-14T10:00:00.000Z")
        XCTAssertNotNil(date)
        XCTAssertEqual(BridgeDateParsing.formatInstant(date!), "2026-06-14T10:00:00.000Z")
    }

    func testParseInstantWithoutFractionalSeconds() {
        let date = BridgeDateParsing.parseInstant("2026-06-14T10:00:00Z")
        XCTAssertNotNil(date)
        XCTAssertEqual(date, BridgeDateParsing.parseInstant("2026-06-14T10:00:00.000Z"))
    }

    func testParseInstantNilAndEmpty() {
        XCTAssertNil(BridgeDateParsing.parseInstant(nil))
        XCTAssertNil(BridgeDateParsing.parseInstant(""))
    }

    func testFormatInstantUsesFractionalZuluSuffix() {
        let date = Date(timeIntervalSince1970: 1_752_489_600)
        let formatted = BridgeDateParsing.formatInstant(date)
        XCTAssertTrue(formatted.hasSuffix("Z"))
        XCTAssertTrue(formatted.contains("."))
    }

    func testParseDateBoundaryDayOnlyStartOfDay() {
        let parsed = BridgeDateParsing.parseDateBoundary("2026-06-14", endOfDay: false)
        XCTAssertNotNil(parsed)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: parsed!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 14)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testParseDateBoundaryDayOnlyEndOfDay() {
        let parsed = BridgeDateParsing.parseDateBoundary("2026-06-14", endOfDay: true)
        XCTAssertNotNil(parsed)
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: parsed!)
        XCTAssertEqual(components.hour, 23)
        XCTAssertEqual(components.minute, 59)
        XCTAssertEqual(components.second, 59)
    }

    func testParseDateBoundaryAcceptsISOInstant() {
        let iso = "2026-06-14T10:00:00.000Z"
        XCTAssertEqual(BridgeDateParsing.parseDateBoundary(iso, endOfDay: false), BridgeDateParsing.parseInstant(iso))
    }

    func testParseInstantRejectsInvalidString() {
        XCTAssertNil(BridgeDateParsing.parseInstant("not-a-date"))
    }

    func testFormatAndParseInstantRoundTrip() {
        let original = Date(timeIntervalSince1970: 1_752_489_600.123)
        let formatted = BridgeDateParsing.formatInstant(original)
        let parsed = BridgeDateParsing.parseInstant(formatted)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(formatted, BridgeDateParsing.formatInstant(parsed!))
    }

    func testParseDateBoundaryNilForMalformedDay() {
        XCTAssertNil(BridgeDateParsing.parseDateBoundary("2026-13-40", endOfDay: false))
    }

    func testParseInstantAcceptsDayOnlyDateString() {
        let parsed = BridgeDateParsing.parseInstant("2026-06-14")
        XCTAssertNotNil(parsed)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: parsed!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 14)
    }

    func testParseDateBoundaryEndOfDayIsAfterStartOfDay() {
        let start = BridgeDateParsing.parseDateBoundary("2026-06-14", endOfDay: false)!
        let end = BridgeDateParsing.parseDateBoundary("2026-06-14", endOfDay: true)!
        XCTAssertLessThan(start, end)
    }
}
