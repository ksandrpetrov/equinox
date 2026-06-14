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

        let matches = PlaudEventMatching.assignMatches(
            events: [event],
            recordings: recordings,
            now: makeDate(year: 2025, month: 6, day: 12, hour: 9, minute: 0),
            calendar: calendar
        )

        let key = PlaudEventMatching.matchKey(eventIdentifier: "EK-1", startDate: eventStart)
        XCTAssertEqual(matches[key]?.fileID, "383169344ae0d5bd925daddb7b5a713e")
        XCTAssertEqual(matches[key]?.source, .auto)
        XCTAssertEqual(matches[key]?.webURL.absoluteString, "https://web.plaud.ai/file/383169344ae0d5bd925daddb7b5a713e")
    }

    func testTwoRecordingsInSameWindowKeepsCloserRecording() {
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

        let matches = PlaudEventMatching.assignMatches(
            events: [event],
            recordings: recordings,
            now: makeDate(year: 2025, month: 6, day: 12, hour: 9, minute: 0),
            calendar: calendar
        )

        let key = PlaudEventMatching.matchKey(eventIdentifier: "EK-2", startDate: eventStart)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[key]?.fileID, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
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

        let matches = PlaudEventMatching.assignMatches(
            events: [event],
            recordings: recordings,
            now: makeDate(year: 2025, month: 6, day: 12, hour: 9, minute: 0),
            calendar: calendar
        )

        let key = PlaudEventMatching.matchKey(eventIdentifier: "EK-3", startDate: eventStart)
        XCTAssertNotNil(matches[key])
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

        let matches = PlaudEventMatching.assignMatches(
            events: [event],
            recordings: recordings,
            now: makeDate(year: 2025, month: 6, day: 12, hour: 9, minute: 0),
            calendar: calendar
        )

        XCTAssertTrue(matches.isEmpty)
    }

    func testMaxOverlapAssignsRecordingToDominantEvent() {
        let eventAStart = makeDate(year: 2025, month: 6, day: 14, hour: 12, minute: 0)
        let eventAEnd = makeDate(year: 2025, month: 6, day: 14, hour: 13, minute: 0)
        let eventBStart = makeDate(year: 2025, month: 6, day: 14, hour: 13, minute: 0)
        let eventBEnd = makeDate(year: 2025, month: 6, day: 14, hour: 14, minute: 0)

        let eventA = PlaudMatchableEvent(
            eventIdentifier: "EK-A",
            title: "Meeting A",
            startDate: eventAStart,
            endDate: eventAEnd
        )
        let eventB = PlaudMatchableEvent(
            eventIdentifier: "EK-B",
            title: "Meeting B",
            startDate: eventBStart,
            endDate: eventBEnd
        )

        let recordingStart = makeDate(year: 2025, month: 6, day: 14, hour: 12, minute: 10)
        let recording = PlaudRecording(
            fileID: "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
            title: "Long recording",
            recordedAt: recordingStart,
            durationSeconds: 65 * 60
        )

        let matches = PlaudEventMatching.assignMatches(
            events: [eventA, eventB],
            recordings: [recording],
            now: makeDate(year: 2025, month: 6, day: 15, hour: 9, minute: 0),
            calendar: calendar
        )

        let keyA = PlaudEventMatching.matchKey(eventIdentifier: "EK-A", startDate: eventAStart)
        let keyB = PlaudEventMatching.matchKey(eventIdentifier: "EK-B", startDate: eventBStart)
        XCTAssertEqual(matches[keyA]?.fileID, "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
        XCTAssertNil(matches[keyB])
    }

    func testRecordingFullyInsideSingleEventMatchesIt() {
        let eventStart = makeDate(year: 2025, month: 6, day: 14, hour: 9, minute: 0)
        let eventEnd = makeDate(year: 2025, month: 6, day: 14, hour: 10, minute: 0)
        let event = PlaudMatchableEvent(
            eventIdentifier: "EK-INSIDE",
            title: "Standup",
            startDate: eventStart,
            endDate: eventEnd
        )
        let recording = PlaudRecording(
            fileID: "ffffffffffffffffffffffffffffffff",
            title: "Standup notes",
            recordedAt: makeDate(year: 2025, month: 6, day: 14, hour: 9, minute: 5),
            durationSeconds: 30 * 60
        )

        let matches = PlaudEventMatching.assignMatches(
            events: [event],
            recordings: [recording],
            now: makeDate(year: 2025, month: 6, day: 15, hour: 9, minute: 0),
            calendar: calendar
        )

        let key = PlaudEventMatching.matchKey(eventIdentifier: "EK-INSIDE", startDate: eventStart)
        XCTAssertEqual(matches[key]?.fileID, "ffffffffffffffffffffffffffffffff")
    }

    func testOverlapSecondsComputesIntersection() {
        let start = makeDate(year: 2025, month: 6, day: 14, hour: 12, minute: 10)
        let end = makeDate(year: 2025, month: 6, day: 14, hour: 13, minute: 15)
        let eventStart = makeDate(year: 2025, month: 6, day: 14, hour: 12, minute: 0)
        let eventEnd = makeDate(year: 2025, month: 6, day: 14, hour: 13, minute: 0)

        let overlap = PlaudEventMatching.overlapSeconds(
            recStart: start,
            recEnd: end,
            eventStart: eventStart,
            eventEnd: eventEnd
        )
        XCTAssertEqual(overlap, 50 * 60, accuracy: 1)
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

    func testDurationSecondsParsesMilliseconds() throws {
        XCTAssertEqual(try XCTUnwrap(PlaudTimestamp.durationSeconds(from: 3_900_000)), 3900, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(PlaudTimestamp.durationSeconds(from: "1800000")), 1800, accuracy: 0.001)
        XCTAssertNil(PlaudTimestamp.durationSeconds(from: nil))
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

        let matches = PlaudEventMatching.assignMatches(
            events: [event],
            recordings: [recording],
            now: utcDate(year: 2026, month: 6, day: 14, hour: 9, minute: 0),
            calendar: utcCalendar
        )

        let key = PlaudEventMatching.matchKey(
            eventIdentifier: "EK-UTC",
            startDate: utcDate(year: 2026, month: 6, day: 11, hour: 12, minute: 0)
        )
        XCTAssertEqual(matches[key]?.fileID, "383169344ae0d5bd925daddb7b5a713e")
        XCTAssertEqual(matches[key]?.webURL.absoluteString, "https://web.plaud.ai/file/383169344ae0d5bd925daddb7b5a713e")
    }

    func testRecordingMatchesMeetingDayNotSummarizationDay() {
        let eventStart = makeDate(year: 2025, month: 5, day: 18, hour: 14, minute: 0)
        let eventEnd = makeDate(year: 2025, month: 5, day: 18, hour: 15, minute: 0)
        let nextDayEventStart = makeDate(year: 2025, month: 5, day: 19, hour: 14, minute: 0)
        let nextDayEventEnd = makeDate(year: 2025, month: 5, day: 19, hour: 15, minute: 0)

        let meetingDayEvent = PlaudMatchableEvent(
            eventIdentifier: "EK-MEETING",
            title: "Weekly Sync",
            startDate: eventStart,
            endDate: eventEnd
        )
        let nextDayEvent = PlaudMatchableEvent(
            eventIdentifier: "EK-NEXT",
            title: "Other Sync",
            startDate: nextDayEventStart,
            endDate: nextDayEventEnd
        )

        // recordedAt reflects actual meeting start; summarization may happen the next day in API metadata.
        let recording = PlaudRecording(
            fileID: "11111111111111111111111111111111",
            title: "05-18 Weekly Sync",
            recordedAt: makeDate(year: 2025, month: 5, day: 18, hour: 14, minute: 5),
            durationSeconds: 45 * 60
        )

        let matches = PlaudEventMatching.assignMatches(
            events: [meetingDayEvent, nextDayEvent],
            recordings: [recording],
            now: makeDate(year: 2025, month: 5, day: 20, hour: 9, minute: 0),
            calendar: calendar
        )

        let meetingKey = PlaudEventMatching.matchKey(eventIdentifier: "EK-MEETING", startDate: eventStart)
        let nextDayKey = PlaudEventMatching.matchKey(eventIdentifier: "EK-NEXT", startDate: nextDayEventStart)
        XCTAssertEqual(matches[meetingKey]?.fileID, "11111111111111111111111111111111")
        XCTAssertNil(matches[nextDayKey])
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
