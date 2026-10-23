import XCTest
@testable import EquinoxKit

@MainActor
final class CalendarNavigationCoordinatorTests: XCTestCase {
    private nonisolated let suite = "equinox.navigation.tests.\(UUID().uuidString)"
    private lazy var defaults = UserDefaults(suiteName: suite)!
    private lazy var preferences = PreferencesStore(defaults: defaults, notificationCenter: NotificationCenter())
    private let calendar = Calendar.equinoxGregorian(timeZone: TimeZone(secondsFromGMT: 0)!)
    private lazy var navigation = CalendarNavigationCoordinator(calendar: calendar, preferences: preferences,
                                                                  now: { Date(timeIntervalSince1970: 1_789_214_400) })

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testSelectionUpdatesDateAndRefreshesOnlyWhenMonthChanges() {
        let initial = CalendarDate(year: 2026, monthIndex: 8, day: 12)
        let cases: [(target: CalendarDate, month: CalendarDate, refreshes: Int)] = [
            (initial, initial, 0),
            (CalendarDate(year: 2026, monthIndex: 8, day: 15), initial, 0),
            (CalendarDate(year: 2026, monthIndex: 7, day: 14), CalendarDate(year: 2026, monthIndex: 7, day: 1), 1),
            (CalendarDate(year: 2026, monthIndex: 9, day: 14), CalendarDate(year: 2026, monthIndex: 9, day: 1), 1),
            (CalendarDate(year: 2027, monthIndex: 8, day: 14), CalendarDate(year: 2027, monthIndex: 8, day: 1), 1),
            (CalendarDate(year: 2027, monthIndex: 0, day: 14), CalendarDate(year: 2027, monthIndex: 0, day: 1), 1)
        ]
        for value in cases {
            navigation.monthDate = initial
            navigation.selectedDate = initial
            navigation.goToToday(isInitialVisibleRange: false)
            let token = navigation.agendaScrollToken
            var refreshes = 0
            navigation.onVisibleGridRangeChanged = { _, _ in refreshes += 1 }

            navigation.selectDate(value.target)

            XCTAssertEqual(navigation.selectedDate, value.target)
            XCTAssertEqual(navigation.monthDate, value.month)
            XCTAssertEqual(refreshes, value.refreshes, "Selection: \(value.target)")
            XCTAssertEqual(navigation.agendaScrollToken, token + 1)
            XCTAssertFalse(navigation.agendaFocusesDayStart)
        }
    }

    func testSyncSelectionFromAgendaScrollDoesNotBumpScrollToken() {
        let tokenBefore = navigation.agendaScrollToken
        let target = navigation.selectedDate.addingDays(1)
        navigation.syncSelectionFromAgendaScroll(target)
        XCTAssertEqual(navigation.selectedDate, target)
        XCTAssertEqual(navigation.agendaScrollToken, tokenBefore)
    }

    func testGoToPreviousMonthPreservesSelectedDay() {
        navigation.selectDate(CalendarDate(year: 2026, monthIndex: 5, day: 14))
        navigation.goToPreviousMonth()
        XCTAssertEqual(navigation.selectedDate, CalendarDate(year: 2026, monthIndex: 4, day: 14))
    }

    func testGoToNextMonthClampsSelectedDayToDestinationMonth() {
        navigation.selectDate(CalendarDate(year: 2026, monthIndex: 0, day: 31))
        navigation.goToNextMonth()
        XCTAssertEqual(navigation.selectedDate, CalendarDate(year: 2026, monthIndex: 1, day: 28))
    }

    func testMonthButtonsPreserveSelectionThroughSkippedLocalDay() throws {
        let apia = Calendar.equinoxGregorian(timeZone: try XCTUnwrap(TimeZone(identifier: "Pacific/Apia")))
        let navigation = CalendarNavigationCoordinator(calendar: apia, preferences: preferences)
        let november30 = CalendarDate(year: 2011, monthIndex: 10, day: 30)
        let december30 = CalendarDate(year: 2011, monthIndex: 11, day: 30)
        let january30 = CalendarDate(year: 2012, monthIndex: 0, day: 30)
        navigation.selectDate(november30)
        navigation.goToNextMonth()
        XCTAssertEqual(navigation.selectedDate, december30)
        XCTAssertTrue(navigation.visibleGridDates.contains(december30))
        navigation.goToNextMonth()
        XCTAssertEqual(navigation.selectedDate, january30)
        navigation.goToPreviousMonth()
        XCTAssertEqual(navigation.selectedDate, december30)
        navigation.goToPreviousMonth()
        XCTAssertEqual(navigation.selectedDate, november30)
    }

    func testNavigationDoesNotLeaveSupportedDateRange() {
        let cases: [(year: Int, month: Int, previous: Bool, next: Bool)] = [
            (1583, 0, false, true), (1583, 1, true, true), (1583, 11, true, true),
            (1584, 0, true, true), (3332, 11, true, true),
            (3333, 0, true, true), (3333, 10, true, true), (3333, 11, true, false)
        ]
        for value in cases {
            navigation.monthDate = CalendarDate(year: value.year, monthIndex: value.month, day: 1)
            XCTAssertEqual(navigation.canGoToPreviousMonth, value.previous, "\(value.year)/\(value.month + 1)")
            XCTAssertEqual(navigation.canGoToNextMonth, value.next, "\(value.year)/\(value.month + 1)")
        }

        navigation.monthDate = CalendarDate(year: CalendarDate.minYear, monthIndex: 0, day: 1)
        navigation.selectedDate = CalendarDate.minimumSupported
        let initialToken = navigation.agendaScrollToken
        navigation.goToPreviousMonth()
        XCTAssertEqual(navigation.selectedDate, CalendarDate.minimumSupported)
        XCTAssertEqual(navigation.agendaScrollToken, initialToken)

        navigation.monthDate = CalendarDate(year: CalendarDate.maxYear, monthIndex: 11, day: 1)
        navigation.selectedDate = CalendarDate.maximumSupported
        navigation.goToNextMonth()
        XCTAssertEqual(navigation.selectedDate, CalendarDate.maximumSupported)
        XCTAssertEqual(navigation.agendaScrollToken, initialToken)

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

    func testRefreshVisibleGridRangeNotifiesOwner() throws {
        var notified: (CalendarDate, CalendarDate)?
        navigation.onVisibleGridRangeChanged = { first, last in
            notified = (first, last)
        }
        navigation.refreshVisibleGridRange()
        let range = try XCTUnwrap(notified)
        XCTAssertLessThanOrEqual(range.0, range.1)
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
        let today = CalendarDate(year: 2026, monthIndex: 8, day: 12)
        let now = today.date(in: calendar)
        let cases: [(start: CalendarDate, initialRange: Bool, refreshes: Int)] = [
            (today, false, 0),
            (CalendarDate(year: 2026, monthIndex: 8, day: 20), false, 0),
            (CalendarDate(year: 2026, monthIndex: 7, day: 12), false, 1),
            (CalendarDate(year: 2025, monthIndex: 8, day: 12), false, 1),
            (CalendarDate(year: 2025, monthIndex: 7, day: 12), false, 1),
            (today, true, 1)
        ]
        for value in cases {
            let navigation = CalendarNavigationCoordinator(calendar: calendar, preferences: preferences,
                                                           now: { now })
            navigation.monthDate = value.start
            navigation.selectedDate = value.start
            navigation.todayDate = today.addingDays(-1)
            var ranges: [(CalendarDate, CalendarDate)] = []
            navigation.onVisibleGridRangeChanged = { ranges.append(($0, $1)) }

            navigation.goToToday(isInitialVisibleRange: value.initialRange)

            XCTAssertEqual(navigation.todayDate, today)
            XCTAssertEqual(navigation.selectedDate, today)
            XCTAssertEqual(navigation.monthDate, today)
            XCTAssertTrue(navigation.agendaFocusesDayStart)
            XCTAssertEqual(navigation.agendaScrollToken, 1)
            XCTAssertEqual(ranges.count, value.refreshes, "From \(value.start), initial range: \(value.initialRange)")
            for range in ranges {
                XCTAssertLessThanOrEqual(range.0, today)
                XCTAssertGreaterThanOrEqual(range.1, today)
            }
        }
    }

    func testRequestAgendaScrollBumpsToken() {
        let tokenBefore = navigation.agendaScrollToken
        navigation.requestAgendaScroll()
        XCTAssertGreaterThan(navigation.agendaScrollToken, tokenBefore)
    }

    func testManualAgendaScrollCancelsPendingRefocusEvenOnSameDay() {
        navigation.isPanelVisible = { true }
        navigation.requestAgendaScroll()
        let token = navigation.agendaScrollToken
        navigation.syncSelectionFromAgendaScroll(navigation.selectedDate)
        navigation.refocusAgendaAfterFetch()
        XCTAssertEqual(navigation.agendaScrollToken, token)
    }

    func testCompletedFocusDoesNotSurviveHiddenPanelOrDifferentSelection() {
        var visible = true
        navigation.isPanelVisible = { visible }
        navigation.requestAgendaScroll()
        let token = navigation.agendaScrollToken
        visible = false
        navigation.refocusAgendaAfterFetch()
        visible = true
        navigation.refocusAgendaAfterFetch()
        XCTAssertEqual(navigation.agendaScrollToken, token)

        navigation.selectDate(navigation.todayDate.addingDays(1))
        let selectionToken = navigation.agendaScrollToken
        navigation.refocusAgendaAfterFetch()
        XCTAssertEqual(navigation.agendaScrollToken, selectionToken)
    }

    func testClockCrossingMidnightUpdatesTodayWithoutMovingSelection() {
        var now = CalendarDate(year: 2026, monthIndex: 8, day: 12).date(in: calendar).addingTimeInterval(86399)
        let navigation = CalendarNavigationCoordinator(calendar: calendar, preferences: preferences, now: { now })
        let selected = navigation.selectedDate
        now = now.addingTimeInterval(2)
        navigation.refreshTodayIfNeeded()
        XCTAssertEqual(navigation.todayDate, CalendarDate(year: 2026, monthIndex: 8, day: 13))
        XCTAssertEqual(navigation.selectedDate, selected)
        navigation.goToToday(isInitialVisibleRange: false)
        XCTAssertEqual(navigation.selectedDate, navigation.todayDate)
        now = now.addingTimeInterval(-2)
        navigation.refreshTodayIfNeeded()
        XCTAssertEqual(navigation.todayDate, selected)
        XCTAssertEqual(navigation.selectedDate, selected.addingDays(1))
    }

}
