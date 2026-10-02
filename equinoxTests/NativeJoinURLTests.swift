import XCTest
@testable import EquinoxKit

final class NativeJoinURLTests: XCTestCase {
    func testZoomRewritePreservesEncodedQueryBytes() throws {
        // '+' and '%2B' can have different meanings to a form-style query parser.
        // Rewriting the destination must not decode and re-encode opaque tokens.
        let query = "pwd=a%2Bb%2F%3D&uname=QA+User&tk=%2526%26x%3Dy&flag&empty="
        let web = try XCTUnwrap(URL(string: "https://zoom.us/j/123?\(query)&conf%6Eo=999"))
        let native = try XCTUnwrap(NativeJoinURL.nativeURLString(from: web))
        XCTAssertEqual(URLComponents(string: native)?.percentEncodedQuery, "confno=123&\(query)")
    }

    func testChimeRewriteDoesNotDropPathComponents() throws {
        for path in ["/1234567890/extra", "/team%2Fmeeting"] {
            let web = try XCTUnwrap(URL(string: "https://chime.aws\(path)"))
            XCTAssertNil(NativeJoinURL.nativeURLString(from: web), path)
            XCTAssertNil(NativeJoinURL.nativeScheme(for: web), path)
        }
        for pin in ["1234567890", "team-personalized-meeting"] {
            let web = try XCTUnwrap(URL(string: "https://chime.aws/\(pin)"))
            XCTAssertEqual(NativeJoinURL.nativeURLString(from: web), "chime://meeting?pin=\(pin)")
        }
    }

    func testZoomRewriteHasOneMeetingIdentifierFromPath() throws {
        for query in ["confno=999", "confno=123&confno=999", "CONFNO=999", "conf%6Eo=999"] {
            let web = try XCTUnwrap(URL(string: "https://zoom.us/j/123?\(query)&pwd=a%2Bb%2F%3D&tk=registration"))
            let native = try XCTUnwrap(NativeJoinURL.nativeURLString(from: web))
            let items = try XCTUnwrap(URLComponents(string: native)?.queryItems)
            XCTAssertEqual(items.filter { $0.name.lowercased() == "confno" }.map(\.value), ["123"])
            XCTAssertEqual(items.first { $0.name == "pwd" }?.value, "a+b/=")
            XCTAssertEqual(items.first { $0.name == "tk" }?.value, "registration")
        }
    }

    func testUnrecognizedZoomPathsKeepTheWebURL() throws {
        for path in ["/j/123/extra", "/j/not-a-meeting-id", "/j/123%2F456"] {
            let web = try XCTUnwrap(URL(string: "https://zoom.us\(path)?pwd=secret"))
            XCTAssertNil(NativeJoinURL.nativeURLString(from: web), path)
            XCTAssertNil(NativeJoinURL.nativeScheme(for: web), path)
        }
    }

    func testWebOnlyMeetingDoesNotQueryInstalledApplications() async throws {
        let url = try XCTUnwrap(URL(string: "https://meet.google.com/abc-defg-hij"))
        let native = await NativeJoinURLResolver.resolveNativeJoinURL(from: url, isAppInstalled: { _ in
            XCTFail("A web-only meeting must not query Launch Services")
            return true
        })
        XCTAssertNil(native)
    }

    func testZoomWebToNativeString() {
        let web = URL(string: "https://zoom.us/j/123456789")!
        let native = NativeJoinURL.nativeURLString(from: web)
        XCTAssertTrue(native?.hasPrefix("zoommtg://") == true)
        XCTAssertTrue(native?.contains("join?confno=123456789") == true)
    }

    func testTeamsWebToNativeString() {
        let web = URL(string: "https://teams.microsoft.com/l/meetup-join/abc")!
        let native = NativeJoinURL.nativeURLString(from: web)
        XCTAssertEqual(native, "msteams://teams.microsoft.com/l/meetup-join/abc")
    }

    func testChimeWebToNativeString() {
        let web = URL(string: "https://chime.aws/meeting123")!
        let native = NativeJoinURL.nativeURLString(from: web)
        XCTAssertEqual(native, "chime://meeting?pin=meeting123")
    }

    func testUnsupportedURLReturnsNil() {
        let web = URL(string: "https://example.com/meeting")!
        XCTAssertNil(NativeJoinURL.nativeURLString(from: web))
    }

    func testNativeSchemeForZoom() {
        let web = URL(string: "https://zoom.us/j/1")!
        XCTAssertEqual(NativeJoinURL.nativeScheme(for: web), "zoommtg://")
    }

    func testZoomGovWebToNativeString() {
        let web = URL(string: "https://zoomgov.com/j/987654321")!
        let native = NativeJoinURL.nativeURLString(from: web)
        XCTAssertTrue(native?.hasPrefix("zoommtg://") == true)
        XCTAssertTrue(native?.contains("join?confno=987654321") == true)
    }

    func testZoomStartAndWebinarPathsRewriteToJoinConfno() {
        let start = URL(string: "https://zoom.us/s/111")!
        let webinar = URL(string: "https://zoom.us/w/222")!
        XCTAssertTrue(NativeJoinURL.nativeURLString(from: start)?.contains("join?confno=111") == true)
        XCTAssertTrue(NativeJoinURL.nativeURLString(from: webinar)?.contains("join?confno=222") == true)
    }

    func testZoomQueryParamsUseAmpersandInNativeLink() {
        let web = URL(string: "https://zoom.us/j/123?pwd=abc")!
        let native = NativeJoinURL.nativeURLString(from: web)
        XCTAssertTrue(native?.contains("join?confno=123&pwd=abc") == true)
        XCTAssertFalse(native?.contains("join?confno=123?pwd") == true)
    }

    func testNativeSchemeForTeamsAndChime() {
        let teams = URL(string: "https://teams.microsoft.com/l/meetup-join/abc")!
        let chime = URL(string: "https://chime.aws/meeting123")!
        XCTAssertEqual(NativeJoinURL.nativeScheme(for: teams), "msteams://")
        XCTAssertEqual(NativeJoinURL.nativeScheme(for: chime), "chime://")
    }

    func testGoogleMeetAndWebexDoNotRewriteToNative() {
        let meet = URL(string: "https://meet.google.com/abc-defg-hij")!
        let webex = URL(string: "https://webex.com/join/room")!
        XCTAssertNil(NativeJoinURL.nativeURLString(from: meet))
        XCTAssertNil(NativeJoinURL.nativeURLString(from: webex))
        XCTAssertNil(NativeJoinURL.nativeScheme(for: meet))
    }

    func testNotesForDisplayStripsNativeZoomVariant() {
        let joinURL = URL(string: "https://zoom.us/j/123456789")!
        let native = NativeJoinURL.nativeURLString(from: joinURL)!
        let notes = "Dial-in\n\(native)\nSee you there"
        let display = JoinURLPresentation.notesForDisplay(notes: notes, excludingJoinURL: joinURL)
        XCTAssertEqual(display, "Dial-in\nSee you there")
    }
}
