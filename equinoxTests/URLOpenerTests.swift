import XCTest
@testable import EquinoxKit

@MainActor
final class URLOpenerTests: XCTestCase {
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
