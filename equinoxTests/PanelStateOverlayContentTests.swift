import XCTest
@testable import EquinoxKit

final class PanelStateOverlayContentTests: XCTestCase {
    func testAuthorizedInitialLoadDoesNotShowFalseNoCalendarsState() {
        XCTAssertEqual(
            PanelStateOverlayContent.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: false,
                fetchError: nil,
                hasCalendars: false,
                hasSelectedCalendars: false
            ),
            .none
        )
    }

    func testCompletedLoadDistinguishesUnavailableAndUnselectedCalendars() {
        XCTAssertEqual(
            PanelStateOverlayContent.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: true,
                fetchError: nil,
                hasCalendars: false,
                hasSelectedCalendars: false
            ),
            .noCalendarsAvailable
        )
        XCTAssertEqual(
            PanelStateOverlayContent.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: true,
                fetchError: nil,
                hasCalendars: true,
                hasSelectedCalendars: false
            ),
            .noCalendarsSelected
        )
    }

    func testPermissionAndFetchErrorsTakePriority() {
        XCTAssertEqual(
            PanelStateOverlayContent.resolve(
                accessStatus: .denied,
                hasCompletedInitialLoad: true,
                fetchError: "stale error",
                hasCalendars: true,
                hasSelectedCalendars: true
            ),
            .permission
        )
        XCTAssertEqual(
            PanelStateOverlayContent.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: false,
                fetchError: "fetch failed",
                hasCalendars: false,
                hasSelectedCalendars: false
            ),
            .fetchError("fetch failed")
        )
    }
}
