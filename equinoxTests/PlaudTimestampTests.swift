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

    func testParseCreatedAtNaiveUTCWithFractionalSeconds() {
        // Plaud `start_at` for app recordings carries 6-digit microseconds and no timezone.
        let date = PlaudTimestamp.parseCreatedAt("2026-06-11T11:04:11.544000")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 11)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 4)
        XCTAssertEqual(components.second, 11)
    }

    func testParseRecordingStartedAtPrefersStartAtOverCreatedAt() {
        // Real shape from the Plaud `files/` endpoint: created_at is the (next-day)
        // summarization time, start_at is the actual recording start.
        let raw: [String: Any] = [
            "created_at": "2026-06-03T10:37:54",
            "start_at": "2026-06-02T13:29:56",
        ]

        let parsed = PlaudTimestamp.parseRecordingStartedAt(from: raw)
        XCTAssertEqual(parsed, PlaudTimestamp.parseCreatedAt("2026-06-02T13:29:56"))
    }

    func testParseRecordingStartedAtPrefersFractionalStartAtOverCreatedAt() {
        let raw: [String: Any] = [
            "created_at": "2026-06-11T12:00:26",
            "start_at": "2026-06-11T11:04:11.544000",
        ]

        let parsed = PlaudTimestamp.parseRecordingStartedAt(from: raw)
        XCTAssertEqual(parsed, PlaudTimestamp.parseCreatedAt("2026-06-11T11:04:11"))
    }

    func testParseRecordingStartedAtFallsBackToCreatedAt() {
        let raw: [String: Any] = [
            "created_at": "2025-05-18T12:00:00",
        ]

        let parsed = PlaudTimestamp.parseRecordingStartedAt(from: raw)
        XCTAssertEqual(
            parsed,
            PlaudTimestamp.parseCreatedAt("2025-05-18T12:00:00")
        )
    }
}
