import XCTest
@testable import equinox

final class PlaudTimestampTests: XCTestCase {
    func testParseEpochSeconds() {
        let date = PlaudTimestamp.parseEpoch(1_700_000_000)
        XCTAssertNotNil(date)
        XCTAssertEqual(date!.timeIntervalSince1970, 1_700_000_000, accuracy: 1.0)
    }

    func testParseEpochMilliseconds() {
        let date = PlaudTimestamp.parseEpoch(1_700_000_000_000)
        XCTAssertNotNil(date)
        XCTAssertEqual(date!.timeIntervalSince1970, 1_700_000_000, accuracy: 1.0)
    }

    func testParseCreatedAtNaiveUTC() {
        let date = PlaudTimestamp.parseCreatedAt("2024-06-01T12:00:00")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 0)
    }
}
