import Foundation

@Observable
@MainActor
final class CalendarNavigationCoordinator {
    let calendar: Calendar
    private let preferences: PreferencesStore

    var monthDate: CalendarDate
    var selectedDate: CalendarDate
    var todayDate: CalendarDate

    /// Bumped after navigation or panel reopen that should scroll the agenda to `selectedDate`.
    private(set) var agendaScrollToken = 0

    /// Direction of the last month navigation for grid transition animation.
    private(set) var monthNavigationDirection: MonthNavigationDirection = .forward

    var isPanelVisible: () -> Bool = { false }
    var onVisibleGridRangeChanged: (CalendarDate, CalendarDate) -> Void = { _, _ in }

    private var awaitingAgendaFocusAfterFetch = false

    enum MonthNavigationDirection {
        case forward
        case backward
    }

    var canGoToPreviousMonth: Bool {
        monthDate.year > CalendarDate.minYear || monthDate.monthIndex > 0
    }

    var canGoToNextMonth: Bool {
        monthDate.year < CalendarDate.maxYear || monthDate.monthIndex < 11
    }

    init(calendar: Calendar, preferences: PreferencesStore) {
        self.calendar = calendar
        self.preferences = preferences
        let today = CalendarDate.today(calendar: calendar)
        monthDate = today
        selectedDate = today
        todayDate = today
    }

    func requestAgendaScroll() {
        agendaScrollToken &+= 1
        if isPanelVisible() {
            awaitingAgendaFocusAfterFetch = true
        }
    }

    func refocusAgendaAfterFetch() {
        guard awaitingAgendaFocusAfterFetch else { return }
        awaitingAgendaFocusAfterFetch = false
        guard isPanelVisible(), selectedDate == todayDate else { return }
        // Consume the request without arming another focus on the next refresh.
        agendaScrollToken &+= 1
    }

    func goToToday(isInitialVisibleRange: Bool) {
        let newToday = CalendarDate.today(calendar: calendar)
        let monthChanged = newToday.monthIndex != monthDate.monthIndex || newToday.year != monthDate.year

        updateNavigationDirection(toward: newToday)
        todayDate = newToday
        monthDate = newToday
        selectedDate = newToday
        if monthChanged || isInitialVisibleRange {
            refreshVisibleGridRange()
        }
        requestAgendaScroll()
    }

    func goToPreviousMonth() {
        guard canGoToPreviousMonth else { return }
        monthNavigationDirection = .backward
        selectDate(selectedDate.addingMonthsPreservingDay(-1, calendar: calendar))
    }

    func goToNextMonth() {
        guard canGoToNextMonth else { return }
        monthNavigationDirection = .forward
        selectDate(selectedDate.addingMonthsPreservingDay(1, calendar: calendar))
    }

    func selectDate(_ date: CalendarDate) {
        applySelection(date, scrollAgenda: true)
    }

    /// Updates calendar selection from agenda scroll without re-scrolling the agenda.
    func syncSelectionFromAgendaScroll(_ date: CalendarDate) {
        awaitingAgendaFocusAfterFetch = false
        applySelection(date, scrollAgenda: false)
    }

    func refreshTodayIfNeeded() {
        let today = CalendarDate.today(calendar: calendar)
        if today != todayDate {
            todayDate = today
        }
    }

    /// Recomputes the visible grid range from `monthDate` + preferences and notifies the owner.
    func refreshVisibleGridRange() {
        let gridDates = visibleGridDates
        guard let rawFirst = gridDates.first, let rawLast = gridDates.last else { return }
        let first = max(rawFirst, CalendarDate.minimumSupported)
        let last = min(rawLast, CalendarDate.maximumSupported)
        guard first <= last else { return }
        onVisibleGridRangeChanged(first, last)
    }

    /// Calendar dates shown in the month grid (single source for UI and fetch range).
    var visibleGridDates: [CalendarDate] {
        monthGridDates(
            monthDate: monthDate,
            weekStartWeekday: preferences.weekStartWeekday,
            numRows: preferences.calendarRowCount
        )
    }

    private func applySelection(_ date: CalendarDate, scrollAgenda: Bool) {
        guard date.isValid else { return }
        let newMonthDate = CalendarDate(year: date.year, monthIndex: date.monthIndex, day: 1)
        let monthChanged = date.monthIndex != monthDate.monthIndex || date.year != monthDate.year
        let selectionChanged = selectedDate != date
        let monthDateChanged = monthChanged && monthDate != newMonthDate

        guard selectionChanged || monthDateChanged else {
            if scrollAgenda {
                requestAgendaScroll()
            }
            return
        }

        if selectionChanged {
            selectedDate = date
        }
        if monthDateChanged {
            updateNavigationDirection(toward: newMonthDate)
            monthDate = newMonthDate
            refreshVisibleGridRange()
        }
        if scrollAgenda {
            requestAgendaScroll()
        }
    }

    private func updateNavigationDirection(toward date: CalendarDate) {
        guard date.year != monthDate.year || date.monthIndex != monthDate.monthIndex else { return }
        monthNavigationDirection = date < monthDate ? .backward : .forward
    }
}
