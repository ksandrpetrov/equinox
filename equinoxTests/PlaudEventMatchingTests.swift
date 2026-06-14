import XCTest
@testable import equinox

final class PlaudEventMatchingTests: XCTestCase {
    private var calendar: Calendar!
    private var timeZone: TimeZone!

    override func setUp() {
        super.setUp()
        timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        calendar = cal
    }

    func testSocServDevHeadsMatchesWeeklyRecordingDespiteTitleMismatch() {
        let eventStart = makeDate(year: 2025, month: 6, day: 11, hour: 10, minute: 0)
        let eventEnd = makeDate(year: 2025, month: 6, day: 11, hour: 11, minute: 0)
        let recordedAt = makeDate(year: 2025, month: 6, day: 11, hour: 10, minute: 8)

        let event = PlaudMatchableEvent(
            eventIdentifier: "EK-1",
            title: "SocServ | Dev Heads",
            startDate: eventStart,
            endDate: eventEnd
        )
        let recordings = [
            PlaudRecording(
                fileID: "383169344ae0d5bd925daddb7b5a713e",
                title: "06-11 Еженедельная встреча по ключевым инициативам и операционным вопросам",
                recordedAt: recordedAt,
                folderSegment: "SocServ Dev",
                hasSummary: true
            ),
        ]

        let match = PlaudEventMatching.match(
            event: event,
            recordings: recordings,
            now: makeDate(year: 2025, month: 6, day: 12, hour: 9, minute: 0),
            calendar: calendar
        )

        XCTAssertEqual(match?.fileID, "383169344ae0d5bd925daddb7b5a713e")
        XCTAssertEqual(match?.source, .auto)
        XCTAssertEqual(match?.webURL.absoluteString, "https://web.plaud.ai/file/383169344ae0d5bd925daddb7b5a713e")
    }

    func testTwoRecordingsInSameWindowReturnsNoMatch() {
        let eventStart = makeDate(year: 2025, month: 6, day: 11, hour: 10, minute: 0)
        let eventEnd = makeDate(year: 2025, month: 6, day: 11, hour: 11, minute: 0)

        let event = PlaudMatchableEvent(
            eventIdentifier: "EK-2",
            title: "SocServ | Dev Heads",
            startDate: eventStart,
            endDate: eventEnd
        )
        let recordings = [
            PlaudRecording(
                fileID: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                title: "Recording A",
                recordedAt: makeDate(year: 2025, month: 6, day: 11, hour: 10, minute: 5),
                folderSegment: nil,
                hasSummary: true
            ),
            PlaudRecording(
                fileID: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                title: "Recording B",
                recordedAt: makeDate(year: 2025, month: 6, day: 11, hour: 10, minute: 15),
                folderSegment: nil,
                hasSummary: false
            ),
        ]

        let match = PlaudEventMatching.match(
            event: event,
            recordings: recordings,
            now: makeDate(year: 2025, month: 6, day: 12, hour: 9, minute: 0),
            calendar: calendar
        )

        XCTAssertNil(match)
    }

    func testRecordingWithoutSummaryStillMatchesWhenTimeAligns() {
        let eventStart = makeDate(year: 2025, month: 6, day: 11, hour: 14, minute: 0)
        let eventEnd = makeDate(year: 2025, month: 6, day: 11, hour: 15, minute: 0)

        let event = PlaudMatchableEvent(
            eventIdentifier: "EK-3",
            title: "Team Sync",
            startDate: eventStart,
            endDate: eventEnd
        )
        let recordings = [
            PlaudRecording(
                fileID: "cccccccccccccccccccccccccccccccc",
                title: "06-11 Team Sync",
                recordedAt: makeDate(year: 2025, month: 6, day: 11, hour: 14, minute: 2),
                folderSegment: nil,
                hasSummary: false
            ),
        ]

        let match = PlaudEventMatching.match(
            event: event,
            recordings: recordings,
            now: makeDate(year: 2025, month: 6, day: 12, hour: 9, minute: 0),
            calendar: calendar
        )

        XCTAssertNotNil(match)
        XCTAssertFalse(match?.hasSummary ?? true)
    }

    func testFutureEventDoesNotMatch() {
        let eventStart = makeDate(year: 2030, month: 1, day: 1, hour: 10, minute: 0)
        let eventEnd = makeDate(year: 2030, month: 1, day: 1, hour: 11, minute: 0)

        let event = PlaudMatchableEvent(
            eventIdentifier: "EK-4",
            title: "Future",
            startDate: eventStart,
            endDate: eventEnd
        )
        let recordings = [
            PlaudRecording(
                fileID: "dddddddddddddddddddddddddddddddd",
                title: "Future",
                recordedAt: eventStart,
                folderSegment: nil,
                hasSummary: true
            ),
        ]

        let match = PlaudEventMatching.match(
            event: event,
            recordings: recordings,
            now: makeDate(year: 2025, month: 6, day: 12, hour: 9, minute: 0),
            calendar: calendar
        )

        XCTAssertNil(match)
    }

    func testFileIDFromPlaudURL() {
        let url = URL(string: "https://web.plaud.ai/file/383169344ae0d5bd925daddb7b5a713e")!
        XCTAssertEqual(PlaudEventMatching.fileID(from: url), "383169344ae0d5bd925daddb7b5a713e")
    }

    func testFileIDFromPlaudURLVariants() {
        let trailingSlash = URL(string: "https://web.plaud.ai/file/383169344ae0d5bd925daddb7b5a713e/")!
        XCTAssertEqual(PlaudEventMatching.fileID(from: trailingSlash), "383169344ae0d5bd925daddb7b5a713e")

        let withQuery = URL(string: "https://web.plaud.ai/file/383169344ae0d5bd925daddb7b5a713e?ref=share")!
        XCTAssertEqual(PlaudEventMatching.fileID(from: withQuery), "383169344ae0d5bd925daddb7b5a713e")

        let upperDashed = URL(string: "https://web.plaud.ai/file/38316934-4AE0-D5BD-925D-ADDB7B5A713E")!
        XCTAssertEqual(PlaudEventMatching.fileID(from: upperDashed), "383169344ae0d5bd925daddb7b5a713e")

        XCTAssertNil(PlaudEventMatching.fileID(from: URL(string: "https://web.plaud.ai/")!))
        XCTAssertNil(PlaudEventMatching.fileID(from: URL(string: "https://example.com/not-a-file")!))
    }

    func testParseCreatedAtTreatsNaiveTimestampAsUTC() {
        // No-timezone timestamps must parse to a fixed UTC instant regardless of the device zone.
        let parsed = PlaudCatalog.parseCreatedAt("2026-05-18T13:19:52")
        XCTAssertEqual(parsed, utcDate(year: 2026, month: 5, day: 18, hour: 13, minute: 19, second: 52))

        let spaced = PlaudCatalog.parseCreatedAt("2026-05-18 13:19:52")
        XCTAssertEqual(spaced, utcDate(year: 2026, month: 5, day: 18, hour: 13, minute: 19, second: 52))
    }

    func testParseCreatedAtAcceptsEpochSecondsAndMillis() {
        let epochSeconds = 1_747_574_392.0
        XCTAssertEqual(PlaudCatalog.parseCreatedAt("\(Int(epochSeconds))"), Date(timeIntervalSince1970: epochSeconds))
        XCTAssertEqual(
            PlaudCatalog.parseCreatedAt("\(Int(epochSeconds * 1000))"),
            Date(timeIntervalSince1970: epochSeconds)
        )
        XCTAssertEqual(
            PlaudCatalog.parseCreatedAt(NSNumber(value: epochSeconds)),
            Date(timeIntervalSince1970: epochSeconds)
        )
        // A bare year is not a plausible epoch and is not a valid date format.
        XCTAssertNil(PlaudCatalog.parseCreatedAt("2026"))
    }

    func testNaiveTimestampParsedAsUTCMatchesUTCEvent() throws {
        // End-to-end guard for the timezone fix: Plaud's naive `created_at` (which is UTC)
        // must align to the calendar's absolute UTC instant. Mirrors the real Jun-11 example
        // (recording 2026-06-11T12:00:26 ↔ a 12:00–13:00 UTC meeting).
        let recordedAt = PlaudCatalog.parseCreatedAt("2026-06-11T12:00:26")
        let event = PlaudMatchableEvent(
            eventIdentifier: "EK-UTC",
            title: "SocServ | Weekly",
            startDate: utcDate(year: 2026, month: 6, day: 11, hour: 12, minute: 0),
            endDate: utcDate(year: 2026, month: 6, day: 11, hour: 13, minute: 0)
        )
        let recording = PlaudRecording(
            fileID: "383169344ae0d5bd925daddb7b5a713e",
            title: "06-11 Еженедельная встреча по ключевым инициативам и операционным вопросам",
            recordedAt: try XCTUnwrap(recordedAt),
            folderSegment: "Unfiled",
            hasSummary: true
        )

        let match = PlaudEventMatching.match(
            event: event,
            recordings: [recording],
            now: utcDate(year: 2026, month: 6, day: 14, hour: 9, minute: 0),
            calendar: utcCalendar
        )

        XCTAssertEqual(match?.fileID, "383169344ae0d5bd925daddb7b5a713e")
        XCTAssertEqual(match?.webURL.absoluteString, "https://web.plaud.ai/file/383169344ae0d5bd925daddb7b5a713e")
    }

    func testMatchKeyUsesEventIdentifierAndStartDate() {
        let start = makeDate(year: 2025, month: 6, day: 11, hour: 10, minute: 0)
        let key = PlaudEventMatching.matchKey(eventIdentifier: "RECURRING", startDate: start)
        XCTAssertEqual(key, "RECURRING|\(start.timeIntervalSince1970)")
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = timeZone
        return calendar.date(from: components)!
    }

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func utcDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(identifier: "UTC")!
        return utcCalendar.date(from: components)!
    }
}
