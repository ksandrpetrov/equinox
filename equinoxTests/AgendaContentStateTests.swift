import XCTest
@testable import EquinoxKit

final class AgendaContentStateTests: XCTestCase {
    func testEmptyRangeRespectsShowEmptyDaysAfterSuccessfulLoad() {
        XCTAssertEqual(AgendaContentState.resolve(
            accessStatus: .authorized, hasCompletedInitialLoad: true,
            hasFetchError: false, hasVisibleEvents: false, showEmptyDays: true
        ), .content)
        XCTAssertEqual(AgendaContentState.resolve(
            accessStatus: .authorized, hasCompletedInitialLoad: true,
            hasFetchError: false, hasVisibleEvents: false, showEmptyDays: false
        ), .empty)
    }

    func testEmptyDaysPreferenceDoesNotBypassLoadingOrAccessState() {
        XCTAssertEqual(AgendaContentState.resolve(
            accessStatus: .authorized, hasCompletedInitialLoad: false,
            hasFetchError: false, hasVisibleEvents: false, showEmptyDays: true
        ), .loading)
        for status in [CalendarAccessStatus.denied, .notDetermined] {
            XCTAssertEqual(AgendaContentState.resolve(
                accessStatus: status, hasCompletedInitialLoad: true,
                hasFetchError: false, hasVisibleEvents: false, showEmptyDays: true
            ), .hidden)
        }
        XCTAssertEqual(AgendaContentState.resolve(
            accessStatus: .authorized, hasCompletedInitialLoad: true,
            hasFetchError: false, hasVisibleEvents: false,
            hasSelectedCalendars: false, showEmptyDays: true
        ), .hidden)
    }

    func testAgendaStaysHiddenUntilCalendarAccessIsAuthorized() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .notDetermined,
                hasCompletedInitialLoad: false,
                hasFetchError: false,
                hasVisibleEvents: false
            ),
            .hidden
        )
    }

    func testAgendaHidesWhenNoCalendarsAreSelected() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: true,
                hasFetchError: false,
                hasVisibleEvents: true,
                hasSelectedCalendars: false
            ),
            .hidden
        )
    }

    func testInitialAuthorizedAgendaShowsLoadingInsteadOfEmptyContent() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: false,
                hasFetchError: false,
                hasVisibleEvents: false
            ),
            .loading
        )
    }

    func testSuccessfulEmptyFetchShowsEmptyState() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: true,
                hasFetchError: false,
                hasVisibleEvents: false
            ),
            .empty
        )
    }

    func testCachedContentRemainsVisibleDuringRefreshError() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: true,
                hasFetchError: true,
                hasVisibleEvents: true
            ),
            .content
        )
    }

    func testInitialFetchErrorWithoutCacheHidesAgendaContent() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .authorized,
                hasCompletedInitialLoad: false,
                hasFetchError: true,
                hasVisibleEvents: false
            ),
            .hidden
        )
    }

    func testAgendaHidesCachedEventsAfterAccessIsRevoked() {
        XCTAssertEqual(
            AgendaContentState.resolve(
                accessStatus: .denied,
                hasCompletedInitialLoad: true,
                hasFetchError: false,
                hasVisibleEvents: true
            ),
            .hidden
        )
    }
}
