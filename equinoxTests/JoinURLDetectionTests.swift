import XCTest
@testable import equinox

final class JoinURLDetectionTests: XCTestCase {
    func testDetectZoomInLocation() {
        let url = JoinURLDetection.detectJoinURL(
            location: "Join at https://zoom.us/j/123456789",
            url: nil,
            notes: nil
        )
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("zoom.us") == true)
    }

    func testDetectTeamsInNotes() {
        let url = JoinURLDetection.detectJoinURL(
            location: nil,
            url: nil,
            notes: "Link: https://teams.microsoft.com/l/meetup-join/abc"
        )
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("teams.microsoft.com") == true)
    }

    func testNoMatchReturnsNil() {
        let url = JoinURLDetection.detectJoinURL(
            location: "Conference room A",
            url: "https://example.com",
            notes: "Bring notes"
        )
        XCTAssertNil(url)
    }

    func testPriorityLocationBeforeNotes() {
        let url = JoinURLDetection.detectJoinURL(
            location: "https://meet.google.com/abc-defg-hij",
            url: nil,
            notes: "https://zoom.us/j/999"
        )
        XCTAssertTrue(url?.absoluteString.contains("meet.google.com") == true)
    }

    func testDetectChimeInLocation() {
        let url = JoinURLDetection.detectJoinURL(
            location: "https://chime.aws/abc123",
            url: nil,
            notes: nil
        )
        XCTAssertTrue(url?.absoluteString.contains("chime.aws") == true)
    }

    func testURLFieldPriorityAfterLocation() {
        let url = JoinURLDetection.detectJoinURL(
            location: nil,
            url: "https://zoom.us/j/555",
            notes: "https://teams.microsoft.com/l/meetup-join/x"
        )
        XCTAssertTrue(url?.absoluteString.contains("zoom.us") == true)
    }

    func testMeetingDisplayNameZoom() {
        let url = URL(string: "https://zoom.us/j/123")!
        XCTAssertEqual(JoinURLPresentation.meetingDisplayName(for: url), "Zoom")
    }

    func testMeetingDisplayNameVK() {
        let url = URL(string: "https://vk.com/call/join/abc")!
        XCTAssertEqual(JoinURLPresentation.meetingDisplayName(for: url), "VK Calls")
    }

    func testNotesForDisplayStripsJoinURL() {
        let joinURL = URL(string: "https://vk.com/call/join/abc")!
        let notes = "Organizer: Alex\nhttps://vk.com/call/join/abc\nRoom 401"
        let display = JoinURLPresentation.notesForDisplay(notes: notes, excludingJoinURL: joinURL)
        XCTAssertEqual(display, "Organizer: Alex\nRoom 401")
    }

    func testNotesForDisplayKeepsNotesWithoutJoinURL() {
        let notes = "Bring laptop"
        XCTAssertEqual(
            JoinURLPresentation.notesForDisplay(notes: notes, excludingJoinURL: nil),
            "Bring laptop"
        )
    }

    func testNotesForDisplayStripsZoomWebAndNativeVariants() {
        let joinURL = URL(string: "https://zoom.us/j/123456789")!
        let notes = "Dial-in info\nhttps://zoom.us/j/123456789\nPassword: 1234"
        let display = JoinURLPresentation.notesForDisplay(notes: notes, excludingJoinURL: joinURL)
        XCTAssertEqual(display, "Dial-in info\nPassword: 1234")
    }

    func testDetectZoomGovURL() {
        let url = JoinURLDetection.detectJoinURL(
            location: "https://zoomgov.com/j/987654321",
            url: nil,
            notes: nil
        )
        XCTAssertTrue(url?.absoluteString.contains("zoomgov.com") == true)
    }

    func testDetectGoogleMeetInURLField() {
        let url = JoinURLDetection.detectJoinURL(
            location: nil,
            url: "https://meet.google.com/xyz-abcd-efg",
            notes: nil
        )
        XCTAssertTrue(url?.absoluteString.contains("meet.google.com") == true)
    }

    func testDetectWebexFaceTimeAndHangouts() {
        let webex = JoinURLDetection.detectJoinURL(location: "https://webex.com/join/room", url: nil, notes: nil)
        let facetime = JoinURLDetection.detectJoinURL(location: "https://facetime.apple.com/join/abc", url: nil, notes: nil)
        let hangouts = JoinURLDetection.detectJoinURL(location: nil, url: "https://hangouts.google.com/call/abc", notes: nil)
        XCTAssertTrue(webex?.absoluteString.contains("webex.com") == true)
        XCTAssertTrue(facetime?.absoluteString.contains("facetime.apple.com") == true)
        XCTAssertTrue(hangouts?.absoluteString.contains("hangouts.google.com") == true)
    }

    func testDetectNativeMeetingSchemeInText() {
        let zoom = JoinURLDetection.detectJoinURL(in: "Open zoommtg://zoom.us/join?confno=123")
        let teams = JoinURLDetection.detectJoinURL(in: "Dial msteams://teams.microsoft.com/l/meetup-join/x")
        XCTAssertNotNil(zoom)
        XCTAssertNotNil(teams)
    }

    func testDetectJoinURLInTextReturnsFirstMeetingLink() {
        let text = "Backup: https://example.com\nPrimary: https://zoom.us/j/111\nAlt: https://teams.microsoft.com/l/meetup-join/y"
        let url = JoinURLDetection.detectJoinURL(in: text)
        XCTAssertTrue(url?.absoluteString.contains("zoom.us") == true)
    }

    func testNotesForDisplayStripsTeamsNativeVariant() {
        let joinURL = URL(string: "https://teams.microsoft.com/l/meetup-join/abc")!
        let notes = "Details\nhttps://teams.microsoft.com/l/meetup-join/abc\nSee you there"
        let display = JoinURLPresentation.notesForDisplay(notes: notes, excludingJoinURL: joinURL)
        XCTAssertEqual(display, "Details\nSee you there")
    }

    func testNotesForDisplayReturnsNilForWhitespaceOnlyInput() {
        XCTAssertNil(JoinURLPresentation.notesForDisplay(notes: "   \n  ", excludingJoinURL: nil))
    }

    func testNotesForDisplayReturnsNilWhenOnlyJoinURLRemains() {
        let joinURL = URL(string: "https://zoom.us/j/123456789")!
        XCTAssertNil(JoinURLPresentation.notesForDisplay(notes: "https://zoom.us/j/123456789", excludingJoinURL: joinURL))
    }

    func testDetectOtherCategoryMeetingProviders() {
        let cases: [(String, String)] = [
            ("https://gotomeeting.com/join/123456789", "other"),
            ("https://ringcentral.com/j/abc123", "other"),
            ("https://bigbluebutton.org/gl/room", "other"),
            ("https://bigbluebutton.example.com/gl/room", "other"),
            ("https://bbb.example.com/join", "other"),
            ("https://meet.jit.si/standup", "other"),
            ("https://indigo.collocall.de/meeting", "other"),
            ("https://public.senfcall.de/room", "other"),
            ("https://workplace.com/meet/abc", "other"),
        ]
        for (link, expectedID) in cases {
            let url = JoinURLDetection.detectJoinURL(
                location: nil,
                url: nil,
                notes: "Join: \(link)"
            )
            XCTAssertNotNil(url, link)
            XCTAssertEqual(MeetingProviderRegistry.match(for: url!)?.id, expectedID, link)
        }
    }

    func testYouCanBookZoomLinkMatchesZoomProvider() {
        let link = "https://youcanbook.me/zoom/alex"
        let url = JoinURLDetection.detectJoinURL(location: nil, url: nil, notes: "Book: \(link)")
        XCTAssertEqual(MeetingProviderRegistry.match(for: url!)?.id, "zoom")
    }

    func testDetectJoinURLInTextIsCaseInsensitive() {
        let url = JoinURLDetection.detectJoinURL(in: "Dial in: HTTPS://ZOOM.US/J/123456789")
        XCTAssertNotNil(url)
        XCTAssertEqual(MeetingProviderRegistry.match(for: url!)?.id, "zoom")
    }

    func testAllRegistryDetectionSubstringsAreDetectableInText() {
        for substring in MeetingProviderRegistry.allDetectionSubstrings {
            let text = Self.urlTextEmbedding(substring)
            XCTAssertNotNil(
                JoinURLDetection.detectJoinURL(in: text),
                "Expected detectable URL for substring: \(substring) in \(text)"
            )
        }
    }

    private static func urlTextEmbedding(_ substring: String) -> String {
        if substring.hasPrefix("http") {
            if substring.hasSuffix("/") || substring.hasSuffix(".") {
                return substring + "room"
            }
            return substring
        }
        if substring.hasPrefix("zoommtg://") {
            return "zoommtg://zoom.us/join?confno=1"
        }
        if substring.hasPrefix("msteams://") {
            return "msteams://teams.microsoft.com/l/meetup-join/abc"
        }
        if substring.hasPrefix("chime://") {
            return "chime://meeting?pin=abc"
        }
        return "Join at https://\(substring)123456789"
    }
}
