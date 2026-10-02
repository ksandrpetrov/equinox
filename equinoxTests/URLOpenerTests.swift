import XCTest
@testable import EquinoxKit

@MainActor
final class URLOpenerTests: XCTestCase {
    func testEventLinksCannotOpenLocalResourcesOrInlineCode() throws {
        for value in ["file:///Applications/Calculator.app", "FILE:///tmp/invitation.command",
                      "javascript:alert(1)", "data:text/html,hello", "relative/path"] {
            let url = try XCTUnwrap(URL(string: value))
            var opened: [URL] = []
            XCTAssertFalse(URLOpener.open(url, using: { opened.append($0); return true }), value)
            XCTAssertTrue(opened.isEmpty, "Untrusted event URL reached Launch Services: \(value)")
        }
    }

    func testUnsafeFallbackIsNotOpenedAfterNativeFailure() throws {
        let native = try XCTUnwrap(URL(string: "zoommtg://zoom.us/join?confno=123"))
        let unsafe = try XCTUnwrap(URL(string: "file:///Applications/Calculator.app"))
        var opened: [URL] = []
        XCTAssertFalse(URLOpener.open(native, fallback: unsafe, using: { opened.append($0); return false }))
        XCTAssertEqual(opened, [native])
    }

    func testSafeFallbackAndExistingCommunicationSchemesRemainAvailable() throws {
        for value in ["https://example.com/agenda", "http://localhost:8080/meeting", "tel:+123",
                      "mailto:qa@example.com", "msteams://teams.microsoft.com/l/meetup-join/abc",
                      "equinox://date/2026-10-02"] {
            let url = try XCTUnwrap(URL(string: value))
            var opened: [URL] = []
            XCTAssertTrue(URLOpener.open(url, using: { opened.append($0); return true }))
            XCTAssertEqual(opened, [url])
        }
        let unsafe = try XCTUnwrap(URL(string: "file:///tmp/meeting.command"))
        let web = try XCTUnwrap(URL(string: "https://example.com/meeting"))
        var opened: [URL] = []
        XCTAssertTrue(URLOpener.open(unsafe, fallback: web, using: { opened.append($0); return true }))
        XCTAssertEqual(opened, [web])
    }

    func testUnavailableNativeAppFallsBackToWebURL() throws {
        let native = try XCTUnwrap(URL(string: "zoommtg://zoom.us/join?confno=123"))
        let web = try XCTUnwrap(URL(string: "https://zoom.us/j/123"))
        var opened: [URL] = []
        XCTAssertTrue(URLOpener.open(native, fallback: web, using: { url in
            opened.append(url)
            return url == web
        }))
        XCTAssertEqual(opened, [native, web])
    }

    func testSuccessfulOpenDoesNotLaunchFallbackAndFailedDuplicateIsNotRetried() throws {
        let url = try XCTUnwrap(URL(string: "https://zoom.us/j/123"))
        var calls = 0
        XCTAssertTrue(URLOpener.open(url, fallback: url, using: { _ in calls += 1; return true }))
        XCTAssertEqual(calls, 1)
        calls = 0
        XCTAssertFalse(URLOpener.open(url, fallback: url, using: { _ in calls += 1; return false }))
        XCTAssertEqual(calls, 1)
    }
}
