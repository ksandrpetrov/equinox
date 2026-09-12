import XCTest
@testable import EquinoxKit

final class MeetingProviderTests: XCTestCase {
    func testShortTeamsLinksKeepOriginalWebURLAndPasscode() throws {
        let url = try XCTUnwrap(URL(string: "https://teams.microsoft.com/meet/1234567890123?p=a%2Bb%2F%3D&context=example"))
        XCTAssertEqual(MeetingProviderRegistry.match(for: url)?.id, "teams")
        XCTAssertEqual(JoinURLDetection.detectJoinURL(location: nil, url: url.absoluteString, notes: nil), url)
        XCTAssertEqual(JoinURLDetection.detectJoinURL(location: nil, url: nil, notes: "Join: \(url.absoluteString)"), url)
        XCTAssertNil(NativeJoinURL.nativeURLString(from: url))
        XCTAssertNil(NativeJoinURL.nativeScheme(for: url))
    }

    func testShortTeamsLinksRejectLookalikeHostsAndUnrelatedPaths() throws {
        for value in ["https://teams.microsoft.com.evil.invalid/meet/123?p=x",
                      "https://evil.invalid/?next=https://teams.microsoft.com/meet/123?p=x",
                      "https://teams.microsoft.com/meetings/123?p=x"] {
            XCTAssertNil(MeetingProviderRegistry.match(for: try XCTUnwrap(URL(string: value))), value)
        }
    }

    func testRegistryCoversKnownProviders() {
        let cases: [(String, String)] = [
            ("https://zoom.us/j/123456789", "zoom"),
            ("https://zoomgov.com/j/123456789", "zoom"),
            ("https://teams.microsoft.com/l/meetup-join/abc", "teams"),
            ("https://chime.aws/meeting123", "chime"),
            ("https://meet.google.com/abc-defg-hij", "googleMeet"),
            ("https://webex.com/join/abc", "webex"),
            ("https://vk.com/call/join/abc", "vk"),
            ("https://facetime.apple.com/join/abc", "facetime"),
            ("https://meet.jit.si/room", "other"),
        ]
        for (link, expectedID) in cases {
            let url = URL(string: link)!
            XCTAssertEqual(MeetingProviderRegistry.match(for: url)?.id, expectedID, link)
        }
    }

    func testFirstProviderWinsWhenMultiplePatternsCouldMatch() {
        let zoom = URL(string: "https://zoom.us/j/1")!
        XCTAssertEqual(MeetingProviderRegistry.match(for: zoom)?.id, "zoom")
        XCTAssertNotEqual(MeetingProviderRegistry.match(for: zoom)?.id, "other")
    }

    func testProvidersWithoutNativeSchemeReturnNilNativeURL() {
        let meet = URL(string: "https://meet.google.com/abc-defg-hij")!
        XCTAssertNil(NativeJoinURL.nativeURLString(from: meet))
        XCTAssertNil(NativeJoinURL.nativeScheme(for: meet))
    }

    func testAllDetectionSubstringsAreNonEmpty() {
        XCTAssertFalse(MeetingProviderRegistry.allDetectionSubstrings.isEmpty)
        XCTAssertTrue(MeetingProviderRegistry.allDetectionSubstrings.allSatisfy { !$0.isEmpty })
    }

    func testDetectionSubstringsFeedJoinURLDetection() {
        let url = JoinURLDetection.detectJoinURL(
            location: "https://meet.jit.si/room",
            url: nil,
            notes: nil
        )
        XCTAssertNotNil(url)
    }

    func testPresentationUsesProviderLabelAndFallback() {
        let vk = URL(string: "https://vk.com/call/join/abc")!
        XCTAssertEqual(JoinURLPresentation.meetingDisplayName(for: vk), "VK Calls")
        XCTAssertEqual(JoinURLPresentation.meetingSystemImage(for: vk), "phone.fill")

        let unknown = URL(string: "https://example.com/not-a-meeting")!
        XCTAssertNil(MeetingProviderRegistry.match(for: unknown))
        XCTAssertEqual(
            JoinURLPresentation.meetingDisplayName(for: unknown),
            String(localized: "Video call", bundle: .equinox, comment: "Generic meeting provider name")
        )
        XCTAssertEqual(JoinURLPresentation.meetingSystemImage(for: unknown), "video.fill")
    }

    func testMatchesIsCaseInsensitive() {
        let url = URL(string: "HTTPS://ZOOM.US/J/123456789")!
        XCTAssertEqual(MeetingProviderRegistry.match(for: url)?.id, "zoom")
    }

    func testProviderMatchingRejectsDeceptiveHostsAndQueryParameters() {
        XCTAssertNil(MeetingProviderRegistry.match(for: URL(string: "https://zoom.us.evil.example/j/123")!))
        XCTAssertNil(MeetingProviderRegistry.match(for: URL(string: "https://evil.example/?next=https://zoom.us/j/123")!))
        XCTAssertEqual(
            MeetingProviderRegistry.match(for: URL(string: "https://us02web.zoom.us/j/123")!)?.id,
            "zoom"
        )
    }

    func testNativeRewriteOnlyUsesSupportedWebMeetingShapes() {
        let zoom = URL(string: "https://us02web.zoom.us/j/123?pwd=secret")!
        XCTAssertEqual(
            NativeJoinURL.nativeURLString(from: zoom),
            "zoommtg://zoom.us/join?confno=123&pwd=secret"
        )

        let personalRoom = URL(string: "https://zoom.us/my/alex")!
        XCTAssertNil(NativeJoinURL.nativeURLString(from: personalRoom))
        XCTAssertNil(NativeJoinURL.nativeScheme(for: personalRoom))

        let bookingPage = URL(string: "https://youcanbook.me/zoom/alex")!
        XCTAssertEqual(MeetingProviderRegistry.match(for: bookingPage)?.id, "zoom")
        XCTAssertNil(NativeJoinURL.nativeURLString(from: bookingPage))
        XCTAssertNil(NativeJoinURL.nativeScheme(for: bookingPage))
    }

    func testNativeSchemeURLsMatchTheirProvider() {
        let zoom = URL(string: "zoommtg://zoom.us/join?confno=1")!
        let teams = URL(string: "msteams://teams.microsoft.com/l/meetup-join/x")!
        let chime = URL(string: "chime://meeting?pin=abc")!
        XCTAssertEqual(MeetingProviderRegistry.match(for: zoom)?.id, "zoom")
        XCTAssertEqual(MeetingProviderRegistry.match(for: teams)?.id, "teams")
        XCTAssertEqual(MeetingProviderRegistry.match(for: chime)?.id, "chime")
    }

    func testNativeSchemeMatchingRejectsUnexpectedHostsAndPaths() {
        XCTAssertNil(MeetingProviderRegistry.match(for: URL(string: "zoommtg://evil.example/join?confno=1")!))
        XCTAssertNil(MeetingProviderRegistry.match(for: URL(string: "msteams://teams.microsoft.com/other")!))
        XCTAssertNil(MeetingProviderRegistry.match(for: URL(string: "chime://evil.example?pin=1")!))
    }

    func testOtherCategoryProvidersMatchGenericLabel() {
        let jit = URL(string: "https://meet.jit.si/room")!
        let provider = MeetingProviderRegistry.match(for: jit)
        XCTAssertEqual(provider?.id, "other")
        XCTAssertEqual(JoinURLPresentation.meetingDisplayName(for: jit), provider?.displayName)
        XCTAssertEqual(JoinURLPresentation.meetingSystemImage(for: jit), "video.fill")
    }

    func testRegistryProviderIDsAreUnique() {
        let ids = MeetingProviderRegistry.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testSupportedNativeMeetingURLsExposeScheme() {
        let cases: [(String, String)] = [
            ("https://zoom.us/j/123", "zoommtg://"),
            ("https://teams.microsoft.com/l/meetup-join/abc", "msteams://"),
            ("https://chime.aws/abc", "chime://"),
        ]
        for (link, expectedScheme) in cases {
            XCTAssertEqual(NativeJoinURL.nativeScheme(for: URL(string: link)!), expectedScheme)
        }
    }
}
