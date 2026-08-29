import XCTest
@testable import equinox

@MainActor
final class CalendarNavigationCoordinatorTests: XCTestCase {
    private let preferences = PreferencesStore.shared
    private let calendar = Calendar(identifier: .gregorian)
    private lazy var navigation = CalendarNavigationCoordinator(calendar: calendar, preferences: preferences)

    func testSelectDateInSameMonthDoesNotChangeMonthDate() {
        let initialMonth = navigation.monthDate
        let target = CalendarDate(year: initialMonth.year, monthIndex: initialMonth.monthIndex, day: 15)
        navigation.selectDate(target)
        XCTAssertEqual(navigation.selectedDate, target)
        XCTAssertEqual(navigation.monthDate, initialMonth)
    }

    func testSelectDateInDifferentMonthUpdatesMonthDate() {
        let target = navigation.selectedDate.addingMonthsPreservingDay(1, calendar: calendar)
        navigation.selectDate(target)
        XCTAssertEqual(navigation.selectedDate, target)
        XCTAssertEqual(navigation.monthDate.day, 1)
        XCTAssertEqual(navigation.monthDate.monthIndex, target.monthIndex)
        XCTAssertEqual(navigation.monthDate.year, target.year)
    }

    func testSelectionUpdatesMonthTransitionDirection() {
        navigation.monthDate = CalendarDate(year: 2026, monthIndex: 5, day: 1)
        navigation.selectedDate = CalendarDate(year: 2026, monthIndex: 5, day: 14)

        navigation.selectDate(CalendarDate(year: 2026, monthIndex: 4, day: 14))
        XCTAssertEqual(navigation.monthNavigationDirection, .backward)

        navigation.selectDate(CalendarDate(year: 2027, monthIndex: 0, day: 14))
        XCTAssertEqual(navigation.monthNavigationDirection, .forward)
    }

    func testSyncSelectionFromAgendaScrollDoesNotBumpScrollToken() {
        let tokenBefore = navigation.agendaScrollToken
        let target = navigation.selectedDate.addingDays(1)
        navigation.syncSelectionFromAgendaScroll(target)
        XCTAssertEqual(navigation.selectedDate, target)
        XCTAssertEqual(navigation.agendaScrollToken, tokenBefore)
    }

    func testSelectDateBumpsAgendaScrollToken() {
        let tokenBefore = navigation.agendaScrollToken
        let target = navigation.selectedDate.addingDays(1)
        navigation.selectDate(target)
        XCTAssertGreaterThan(navigation.agendaScrollToken, tokenBefore)
    }

    func testGoToPreviousMonthSetsBackwardDirection() {
        navigation.goToPreviousMonth()
        XCTAssertEqual(navigation.monthNavigationDirection, .backward)
    }

    func testGoToNextMonthSetsForwardDirection() {
        navigation.goToNextMonth()
        XCTAssertEqual(navigation.monthNavigationDirection, .forward)
    }

    func testNavigationDoesNotLeaveSupportedDateRange() {
        navigation.monthDate = CalendarDate(year: CalendarDate.minYear, monthIndex: 0, day: 1)
        navigation.selectedDate = CalendarDate.minimumSupported
        XCTAssertFalse(navigation.canGoToPreviousMonth)
        navigation.goToPreviousMonth()
        XCTAssertEqual(navigation.selectedDate, CalendarDate.minimumSupported)

        navigation.monthDate = CalendarDate(year: CalendarDate.maxYear, monthIndex: 11, day: 1)
        navigation.selectedDate = CalendarDate.maximumSupported
        XCTAssertFalse(navigation.canGoToNextMonth)
        navigation.goToNextMonth()
        XCTAssertEqual(navigation.selectedDate, CalendarDate.maximumSupported)

        navigation.selectDate(CalendarDate(year: CalendarDate.maxYear + 1, monthIndex: 0, day: 1))
        XCTAssertEqual(navigation.selectedDate, CalendarDate.maximumSupported)
    }

    func testVisibleFetchRangeClampsAdjacentGridDaysAtBoundary() {
        navigation.monthDate = CalendarDate.minimumSupported
        var fetchedRange: (CalendarDate, CalendarDate)?
        navigation.onVisibleGridRangeChanged = { fetchedRange = ($0, $1) }

        navigation.refreshVisibleGridRange()

        XCTAssertEqual(fetchedRange?.0, CalendarDate.minimumSupported)
        XCTAssertTrue(fetchedRange?.1.isValid == true)
    }

    func testRefreshVisibleGridRangeNotifiesOwner() {
        var notified: (CalendarDate, CalendarDate)?
        navigation.onVisibleGridRangeChanged = { first, last in
            notified = (first, last)
        }
        navigation.refreshVisibleGridRange()
        XCTAssertNotNil(notified)
        XCTAssertLessThanOrEqual(notified!.0, notified!.1)
    }

    func testWeekStartWeekdayChangeUpdatesVisibleGridRange() {
        let originalWeekStart = preferences.weekStartWeekday
        defer { preferences.weekStartWeekday = originalWeekStart }

        var firstRange: (CalendarDate, CalendarDate)?
        var secondRange: (CalendarDate, CalendarDate)?
        navigation.onVisibleGridRangeChanged = { first, last in
            if firstRange == nil {
                firstRange = (first, last)
            } else {
                secondRange = (first, last)
            }
        }

        navigation.refreshVisibleGridRange()
        preferences.weekStartWeekday = (originalWeekStart + 1) % 7
        navigation.refreshVisibleGridRange()

        XCTAssertNotNil(firstRange)
        XCTAssertNotNil(secondRange)
        XCTAssertNotEqual(firstRange?.0, secondRange?.0)
    }

    func testGoToTodayUpdatesSelectionAndScrollToken() {
        let tokenBefore = navigation.agendaScrollToken
        navigation.goToToday(isInitialVisibleRange: false)
        XCTAssertEqual(navigation.selectedDate, navigation.todayDate)
        XCTAssertGreaterThan(navigation.agendaScrollToken, tokenBefore)
    }

    func testRequestAgendaScrollBumpsToken() {
        let tokenBefore = navigation.agendaScrollToken
        navigation.requestAgendaScroll()
        XCTAssertGreaterThan(navigation.agendaScrollToken, tokenBefore)
    }

    func testRefreshTodayIfNeededUpdatesTodayDateWhenDayChanges() {
        let staleToday = navigation.todayDate.addingDays(-1)
        navigation.todayDate = staleToday
        navigation.refreshTodayIfNeeded()
        XCTAssertEqual(navigation.todayDate, CalendarDate.today(calendar: calendar))
    }
}
