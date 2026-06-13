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
}
