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

    func testWeeklyMeetingMatchesSingleRecordingDespiteTitleMismatch() {
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
                recordedAt: recordedAt
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
                recordedAt: makeDate(year: 2025, month: 6, day: 11, hour: 10, minute: 5)
            ),
            PlaudRecording(
                fileID: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                title: "Recording B",
                recordedAt: makeDate(year: 2025, month: 6, day: 11, hour: 10, minute: 15)
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

    func testSingleRecordingMatchesWhenTimeAligns() {
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
                recordedAt: makeDate(year: 2025, month: 6, day: 11, hour: 14, minute: 2)
            ),
        ]

        let match = PlaudEventMatching.match(
            event: event,
            recordings: recordings,
            now: makeDate(year: 2025, month: 6, day: 12, hour: 9, minute: 0),
            calendar: calendar
        )

        XCTAssertNotNil(match)
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
                recordedAt: eventStart
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
        let parsed = PlaudTimestamp.parseCreatedAt("2026-05-18T13:19:52")
        XCTAssertEqual(parsed, utcDate(year: 2026, month: 5, day: 18, hour: 13, minute: 19, second: 52))

        let spaced = PlaudTimestamp.parseCreatedAt("2026-05-18 13:19:52")
        XCTAssertEqual(spaced, utcDate(year: 2026, month: 5, day: 18, hour: 13, minute: 19, second: 52))
    }

    func testParseCreatedAtAcceptsEpochSecondsAndMillis() {
        let epochSeconds = 1_747_574_392.0
        XCTAssertEqual(PlaudTimestamp.parseCreatedAt("\(Int(epochSeconds))"), Date(timeIntervalSince1970: epochSeconds))
        XCTAssertEqual(
            PlaudTimestamp.parseCreatedAt("\(Int(epochSeconds * 1000))"),
            Date(timeIntervalSince1970: epochSeconds)
        )
        XCTAssertEqual(
            PlaudTimestamp.parseCreatedAt(NSNumber(value: epochSeconds)),
            Date(timeIntervalSince1970: epochSeconds)
        )
        XCTAssertNil(PlaudTimestamp.parseCreatedAt("2026"))
    }

    func testNaiveTimestampParsedAsUTCMatchesUTCEvent() throws {
        let recordedAt = PlaudTimestamp.parseCreatedAt("2026-06-11T12:00:26")
        let event = PlaudMatchableEvent(
            eventIdentifier: "EK-UTC",
            title: "SocServ | Weekly",
            startDate: utcDate(year: 2026, month: 6, day: 11, hour: 12, minute: 0),
            endDate: utcDate(year: 2026, month: 6, day: 11, hour: 13, minute: 0)
        )
        let recording = PlaudRecording(
            fileID: "383169344ae0d5bd925daddb7b5a713e",
            title: "06-11 Еженедельная встреча по ключевым инициативам и операционным вопросам",
            recordedAt: try XCTUnwrap(recordedAt)
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
