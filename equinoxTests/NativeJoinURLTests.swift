import XCTest
@testable import equinox

final class NativeJoinURLTests: XCTestCase {
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
