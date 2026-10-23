import XCTest
@testable import EquinoxKit

final class JoinURLDetectionTests: XCTestCase {
    func testProviderAuthorityCannotBeSmuggledThroughCredentialsPathQueryOrFragment() throws {
        for meeting in ["zoom.us/j/123", "teams.microsoft.com/l/meetup-join/abc", "chime.aws/123",
                        "meet.google.com/abc-defg-hij", "facetime.apple.com/join/abc", "vk.com/call/abc"] {
            let parts = meeting.split(separator: "/", maxSplits: 1)
            let host = String(parts[0])
            let path = "/" + parts[1]
            for value in ["https://\(host).attacker.test\(path)", "https://\(host)@attacker.test\(path)",
                          "https://attacker.test/\(meeting)", "https://attacker.test/?next=https://\(meeting)",
                          "https://attacker.test/#https://\(meeting)"] {
                let url = try XCTUnwrap(URL(string: value))
                XCTAssertNil(MeetingProviderRegistry.match(for: url), value)
                XCTAssertNil(NativeJoinURL.nativeURLString(from: url), value)
                XCTAssertNil(JoinURLDetection.detectJoinURL(in: "📅 Join: \(value)"), value)
            }
        }
    }

    func testConcurrentDetectionAndUnicodeNoteCleanupStayIndependent() async {
        await withTaskGroup(of: Void.self) { group in
            for task in 0..<8 {
                group.addTask {
                    for index in 0..<100 {
                        let link = "https://zoom.us/j/\(task * 100 + index)?pwd=a%2Bb%2F%3D"
                        let notes = "👨‍👩‍👧‍👦 План e\u{301}\n\n  \(link)\n  Не удалять \(task):\(index)"
                        let detected = JoinURLDetection.detectJoinURL(in: notes)
                        XCTAssertEqual(detected?.absoluteString, link)
                        XCTAssertEqual(JoinURLDetection.notesForDisplay(notes: notes, excludingJoinURL: detected),
                                       "👨‍👩‍👧‍👦 План e\u{301}\n\n  Не удалять \(task):\(index)")
                    }
                }
            }
        }
    }

    func testDetectZoomInLocation() {
        let url = JoinURLDetection.detectJoinURL(
            location: "Join at https://zoom.us/j/123456789",
            url: nil,
            notes: nil
        )
        XCTAssertEqual(url?.absoluteString, "https://zoom.us/j/123456789")
    }

    func testDetectTeamsInNotes() {
        let url = JoinURLDetection.detectJoinURL(
            location: nil,
            url: nil,
            notes: "Link: https://teams.microsoft.com/l/meetup-join/abc"
        )
        XCTAssertEqual(url?.absoluteString, "https://teams.microsoft.com/l/meetup-join/abc")
    }

    func testNoMatchReturnsNil() {
        let url = JoinURLDetection.detectJoinURL(
            location: "Conference room A",
            url: "https://example.com",
            notes: "Bring notes"
        )
        XCTAssertNil(url)
    }

    func testDeceptiveMeetingTextDoesNotProduceJoinAction() {
        XCTAssertNil(JoinURLDetection.detectJoinURL(in: "https://evil.example/?next=https://zoom.us/j/123"))
        XCTAssertNil(JoinURLDetection.detectJoinURL(in: "https://zoom.us.evil.example/j/123"))
    }

    func testPriorityLocationBeforeNotes() {
        let url = JoinURLDetection.detectJoinURL(
            location: "https://meet.google.com/abc-defg-hij",
            url: nil,
            notes: "https://zoom.us/j/999"
        )
        XCTAssertEqual(url?.absoluteString, "https://meet.google.com/abc-defg-hij")
    }

    func testDetectChimeInLocation() {
        let url = JoinURLDetection.detectJoinURL(
            location: "https://chime.aws/abc123",
            url: nil,
            notes: nil
        )
        XCTAssertEqual(url?.absoluteString, "https://chime.aws/abc123")
    }

    func testURLFieldPriorityAfterLocation() {
        let url = JoinURLDetection.detectJoinURL(
            location: nil,
            url: "https://zoom.us/j/555",
            notes: "https://teams.microsoft.com/l/meetup-join/x"
        )
        XCTAssertEqual(url?.absoluteString, "https://zoom.us/j/555")
    }

    func testMeetingDisplayNameZoom() {
        let url = URL(string: "https://zoom.us/j/123")!
        XCTAssertEqual(JoinURLPresentation.meetingDisplayName(for: url), "Zoom")
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

    func testNotesKeepParagraphsWhenMeetingLinkComesFromAnotherField() throws {
        let join = try XCTUnwrap(URL(string: "https://zoom.us/j/123"))
        let notes = "Agenda\n\n  1. Introduction\n  2. Discussion\n\nBring notes"
        XCTAssertEqual(JoinURLDetection.notesForDisplay(notes: notes, excludingJoinURL: join), notes)
    }

    func testRemovingMeetingLinePreservesUnrelatedParagraphsAndIndentation() throws {
        let join = try XCTUnwrap(URL(string: "https://zoom.us/j/123"))
        for newline in ["\n", "\r\n"] {
            let notes = ["📅 Agenda", "", "  \(join.absoluteString)  ", "  1. Introduction", "",
                         "  2. Discussion", "", "See you there"].joined(separator: newline)
            let expected = ["📅 Agenda", "", "  1. Introduction", "", "  2. Discussion", "",
                            "See you there"].joined(separator: newline)
            XCTAssertEqual(JoinURLDetection.notesForDisplay(notes: notes, excludingJoinURL: join), expected)
        }
    }

    func testNotesRemovalPreservesOtherLinksWithTheSamePrefix() throws {
        let join = try XCTUnwrap(URL(string: "https://zoom.us/j/123"))
        let otherLinks = [
            "https://zoom.us/j/123456789",
            "https://zoom.us/j/123?pwd=secret",
            "https://example.com/?next=https://zoom.us/j/123",
        ]
        for other in otherLinks {
            let notes = "\(join.absoluteString)\nДругая встреча: \(other)"
            XCTAssertEqual(
                JoinURLPresentation.notesForDisplay(notes: notes, excludingJoinURL: join),
                "Другая встреча: \(other)", other
            )
        }
    }

    func testNotesRemovalHandlesRepeatedLinksAndUnicodeRanges() throws {
        let join = try XCTUnwrap(URL(string: "https://zoom.us/j/123"))
        XCTAssertEqual(
            JoinURLPresentation.notesForDisplay(
                notes: "📅 Встреча\n\(join.absoluteString)\n\(join.absoluteString)\nПароль: 123",
                excludingJoinURL: join
            ),
            "📅 Встреча\nПароль: 123"
        )
    }

    func testNotesForDisplayStripsZoomWebAndNativeVariants() {
        let joinURL = URL(string: "https://zoom.us/j/123456789")!
        let notes = "Dial-in info\nhttps://zoom.us/j/123456789\nPassword: 1234"
        let display = JoinURLPresentation.notesForDisplay(notes: notes, excludingJoinURL: joinURL)
        XCTAssertEqual(display, "Dial-in info\nPassword: 1234")
    }

    func testSourceJoinURLKeepsWebURLWhenActionUsesNativeScheme() {
        let webURL = URL(string: "https://zoom.us/j/123456789")!
        let nativeURL = URL(string: "zoommtg://zoom.us/join?confno=123456789")!
        let notes = "\(webURL.absoluteString)"

        let source = JoinURLPresentation.sourceJoinURL(
            location: nil,
            eventURL: nil,
            notes: notes,
            fallback: nativeURL
        )

        XCTAssertEqual(source, webURL)
        XCTAssertNil(JoinURLPresentation.notesForDisplay(notes: notes, excludingJoinURL: source))
    }

    func testSupplementalEventURLHidesMeetingURLButKeepsIndependentLink() {
        let joinURL = URL(string: "https://zoom.us/j/123456789")!
        let documentURL = URL(string: "https://example.com/agenda")!

        XCTAssertNil(
            JoinURLPresentation.supplementalEventURL(eventURL: joinURL, sourceJoinURL: joinURL)
        )
        XCTAssertEqual(
            JoinURLPresentation.supplementalEventURL(eventURL: documentURL, sourceJoinURL: joinURL),
            documentURL
        )
    }

    func testDetectZoomGovURL() {
        let url = JoinURLDetection.detectJoinURL(
            location: "https://zoomgov.com/j/987654321",
            url: nil,
            notes: nil
        )
        XCTAssertEqual(url?.absoluteString, "https://zoomgov.com/j/987654321")
    }

    func testDetectGoogleMeetInURLField() {
        let url = JoinURLDetection.detectJoinURL(
            location: nil,
            url: "https://meet.google.com/xyz-abcd-efg",
            notes: nil
        )
        XCTAssertEqual(url?.absoluteString, "https://meet.google.com/xyz-abcd-efg")
    }

    func testDetectWebexFaceTimeAndHangouts() {
        let webex = JoinURLDetection.detectJoinURL(location: "https://webex.com/join/room", url: nil, notes: nil)
        let facetime = JoinURLDetection.detectJoinURL(location: "https://facetime.apple.com/join/abc", url: nil, notes: nil)
        let hangouts = JoinURLDetection.detectJoinURL(location: nil, url: "https://hangouts.google.com/call/abc", notes: nil)
        XCTAssertEqual(webex?.absoluteString, "https://webex.com/join/room")
        XCTAssertEqual(facetime?.absoluteString, "https://facetime.apple.com/join/abc")
        XCTAssertEqual(hangouts?.absoluteString, "https://hangouts.google.com/call/abc")
    }

    func testDetectNativeMeetingSchemeInText() {
        let zoom = JoinURLDetection.detectJoinURL(in: "Open zoommtg://zoom.us/join?confno=123")
        let teams = JoinURLDetection.detectJoinURL(in: "Dial msteams://teams.microsoft.com/l/meetup-join/x")
        XCTAssertEqual(zoom?.absoluteString, "zoommtg://zoom.us/join?confno=123")
        XCTAssertEqual(teams?.absoluteString, "msteams://teams.microsoft.com/l/meetup-join/x")
    }

    func testDetectJoinURLInTextReturnsFirstMeetingLink() {
        let text = "Backup: https://example.com\nPrimary: https://zoom.us/j/111\nAlt: https://teams.microsoft.com/l/meetup-join/y"
        let url = JoinURLDetection.detectJoinURL(in: text)
        XCTAssertEqual(url?.absoluteString, "https://zoom.us/j/111")
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
            XCTAssertEqual(url?.absoluteString, link)
            XCTAssertEqual(url.flatMap { MeetingProviderRegistry.match(for: $0) }?.id, expectedID, link)
        }
    }

    func testYouCanBookZoomLinkMatchesZoomProvider() {
        let link = "https://youcanbook.me/zoom/alex"
        let url = JoinURLDetection.detectJoinURL(location: nil, url: nil, notes: "Book: \(link)")
        XCTAssertEqual(url.flatMap { MeetingProviderRegistry.match(for: $0) }?.id, "zoom")
    }

    func testDetectJoinURLInTextIsCaseInsensitive() {
        let url = JoinURLDetection.detectJoinURL(in: "Dial in: HTTPS://ZOOM.US/J/123456789")
        XCTAssertNotNil(url)
        XCTAssertEqual(url.flatMap { MeetingProviderRegistry.match(for: $0) }?.id, "zoom")
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
        let suffix = substring.hasSuffix("/") || substring.hasSuffix(".") ? "room" : ""
        let path = substring.contains("/") ? substring + suffix : substring + "/room"
        return "Join at https://\(path)"
    }
}
