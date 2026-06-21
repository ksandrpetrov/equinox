import XCTest
@testable import equinox

final class MeetingProviderTests: XCTestCase {
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
            String(localized: "Video call", comment: "Generic meeting provider name")
        )
        XCTAssertEqual(JoinURLPresentation.meetingSystemImage(for: unknown), "video.fill")
    }

    func testMatchesIsCaseInsensitive() {
        let url = URL(string: "HTTPS://ZOOM.US/J/123456789")!
        XCTAssertEqual(MeetingProviderRegistry.match(for: url)?.id, "zoom")
    }

    func testNativeSchemeURLsMatchTheirProvider() {
        let zoom = URL(string: "zoommtg://zoom.us/join?confno=1")!
        let teams = URL(string: "msteams://teams.microsoft.com/l/meetup-join/x")!
        let chime = URL(string: "chime://meeting?pin=abc")!
        XCTAssertEqual(MeetingProviderRegistry.match(for: zoom)?.id, "zoom")
        XCTAssertEqual(MeetingProviderRegistry.match(for: teams)?.id, "teams")
        XCTAssertEqual(MeetingProviderRegistry.match(for: chime)?.id, "chime")
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

    func testProvidersWithNativeSchemeExposeScheme() {
        for provider in MeetingProviderRegistry.all where provider.nativeScheme != nil {
            XCTAssertFalse(provider.nativeScheme!.isEmpty)
            let sample = URL(string: provider.detectionSubstrings.first { $0.hasPrefix("http") } ?? "https://example.com")!
            if let matched = MeetingProviderRegistry.match(for: sample), matched.id == provider.id {
                XCTAssertEqual(NativeJoinURL.nativeScheme(for: sample), provider.nativeScheme)
            }
        }
    }
}
