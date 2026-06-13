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
}
