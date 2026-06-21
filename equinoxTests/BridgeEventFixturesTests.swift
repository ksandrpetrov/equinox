import XCTest
@testable import equinox

/// Golden JSON keys shared with `mcp/test/fixtures/bridge-events.json`.
enum BridgeEventFixtures {
    static let fullEventKeys: Set<String> = [
        "eventIdentifier", "calendarItemIdentifier", "title", "location", "notes", "url",
        "startDate", "endDate", "isAllDay", "joinURL", "calendarIdentifier", "calendarTitle",
        "calendarColorHex", "allowsContentModifications", "hasAttendees", "participationStatus",
    ]

    static let minimalEventKeys: Set<String> = [
        "calendarItemIdentifier", "title", "startDate", "endDate", "isAllDay",
        "calendarIdentifier", "calendarTitle", "calendarColorHex",
        "allowsContentModifications", "hasAttendees",
    ]

    static let fullEventJSON = """
    {"eventIdentifier":"evt-full-1","calendarItemIdentifier":"item-full-1","title":"Team Sync","location":"Room A","notes":"Agenda in doc","url":"https://example.com/doc","startDate":"2026-06-14T10:00:00.000Z","endDate":"2026-06-14T11:00:00.000Z","isAllDay":false,"joinURL":"https://zoom.us/j/123456789","calendarIdentifier":"cal-1","calendarTitle":"Work","calendarColorHex":"#FF0000","allowsContentModifications":true,"hasAttendees":true,"participationStatus":"accepted"}
    """

    static let minimalEventJSON = """
    {"calendarItemIdentifier":"item-minimal-1","title":"Focus time","startDate":"2026-06-14T10:00:00.000Z","endDate":"2026-06-14T11:00:00.000Z","isAllDay":false,"calendarIdentifier":"cal-1","calendarTitle":"Work","calendarColorHex":"#FF0000","allowsContentModifications":true,"hasAttendees":false}
    """

    static let declinedEventJSON = """
    {"eventIdentifier":"evt-declined-1","calendarItemIdentifier":"item-declined-1","title":"Optional standup","startDate":"2026-06-15T09:00:00.000Z","endDate":"2026-06-15T09:15:00.000Z","isAllDay":false,"calendarIdentifier":"cal-1","calendarTitle":"Work","calendarColorHex":"#FF0000","allowsContentModifications":false,"hasAttendees":true,"participationStatus":"declined"}
    """
}

final class BridgeEventFixturesTests: XCTestCase {
    func testFullFixtureJSONKeys() throws {
        let data = Data(BridgeEventFixtures.fullEventJSON.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(Set(object?.keys.map { $0 } ?? []), BridgeEventFixtures.fullEventKeys)
    }

    func testMinimalFixtureJSONKeys() throws {
        let data = Data(BridgeEventFixtures.minimalEventJSON.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(Set(object?.keys.map { $0 } ?? []), BridgeEventFixtures.minimalEventKeys)
    }

    func testDeclinedFixtureParticipationStatus() throws {
        let data = Data(BridgeEventFixtures.declinedEventJSON.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["participationStatus"] as? String, "declined")
        XCTAssertEqual(
            EventParticipationMapping.bridgeStatusName(hasAttendees: true, eventKitRawValue: 3),
            "declined"
        )
    }

    func testJoinURLDetectionMatchesFixtureJoinURL() {
        let url = JoinURLDetection.detectJoinURL(
            location: nil,
            url: nil,
            notes: "Join https://zoom.us/j/123456789"
        )
        XCTAssertEqual(url?.absoluteString, "https://zoom.us/j/123456789")
    }

    func testFixtureDatesParseAsBridgeInstants() throws {
        for json in [
            BridgeEventFixtures.fullEventJSON,
            BridgeEventFixtures.minimalEventJSON,
            BridgeEventFixtures.declinedEventJSON,
        ] {
            let data = Data(json.utf8)
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            for key in ["startDate", "endDate"] {
                let value = object?[key] as? String
                XCTAssertNotNil(BridgeDateParsing.parseInstant(value))
            }
        }
    }

    func testMinimalFixtureOmitsOptionalBridgeFields() throws {
        let data = Data(BridgeEventFixtures.minimalEventJSON.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNil(object?["eventIdentifier"])
        XCTAssertNil(object?["joinURL"])
        XCTAssertNil(object?["participationStatus"])
    }

    func testBridgeAndGUIDetectSameJoinURLFromEventFields() {
        let fields: [(String?, String?, String?, String)] = [
            ("https://zoom.us/j/123", nil, nil, "https://zoom.us/j/123"),
            (nil, "https://teams.microsoft.com/l/meetup-join/x", nil, "https://teams.microsoft.com/l/meetup-join/x"),
            (nil, nil, "Join https://meet.google.com/abc-defg-hij", "https://meet.google.com/abc-defg-hij"),
        ]
        for (location, url, notes, expected) in fields {
            let detected = JoinURLDetection.detectJoinURL(location: location, url: url, notes: notes)
            XCTAssertEqual(detected?.absoluteString, expected)
        }
    }

    func testFixturesMatchMCPGoldenFile() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = repoRoot
            .appendingPathComponent("mcp/test/fixtures/bridge-events.json")
        let data = try Data(contentsOf: fixtureURL)
        let events = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(events?.count, 3)
        XCTAssertEqual(Set(events?[0].keys.map { $0 } ?? []), BridgeEventFixtures.fullEventKeys)
        XCTAssertEqual(Set(events?[1].keys.map { $0 } ?? []), BridgeEventFixtures.minimalEventKeys)
        XCTAssertEqual(events?[2]["participationStatus"] as? String, "declined")
    }

    func testFullFixtureJoinURLMatchesMeetingProvider() throws {
        let data = Data(BridgeEventFixtures.fullEventJSON.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let joinURLString = object?["joinURL"] as? String
        let joinURL = URL(string: joinURLString!)
        XCTAssertEqual(MeetingProviderRegistry.match(for: joinURL!)?.id, "zoom")
    }

    func testSwiftFixtureJSONMatchesInlineGoldenStrings() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = repoRoot
            .appendingPathComponent("mcp/test/fixtures/bridge-events.json")
        let fileData = try Data(contentsOf: fixtureURL)
        let fileEvents = try JSONSerialization.jsonObject(with: fileData) as? [[String: Any]]
        let inlineEvents = [
            try JSONSerialization.jsonObject(with: Data(BridgeEventFixtures.fullEventJSON.utf8)) as? [String: Any],
            try JSONSerialization.jsonObject(with: Data(BridgeEventFixtures.minimalEventJSON.utf8)) as? [String: Any],
            try JSONSerialization.jsonObject(with: Data(BridgeEventFixtures.declinedEventJSON.utf8)) as? [String: Any],
        ]
        zip(fileEvents ?? [], inlineEvents).forEach { fileEvent, inlineEvent in
            XCTAssertEqual(fileEvent["calendarItemIdentifier"] as? String, inlineEvent?["calendarItemIdentifier"] as? String)
            XCTAssertEqual(fileEvent["title"] as? String, inlineEvent?["title"] as? String)
            XCTAssertEqual(fileEvent["participationStatus"] as? String, inlineEvent?["participationStatus"] as? String)
        }
    }
}
