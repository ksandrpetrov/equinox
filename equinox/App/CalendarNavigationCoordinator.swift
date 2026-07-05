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

    private(set) var awaitingAgendaFocusAfterFetch = false

    enum MonthNavigationDirection {
        case forward
        case backward
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

    func clearAwaitingAgendaFocusAfterFetch() {
        awaitingAgendaFocusAfterFetch = false
    }

    func goToToday(isInitialVisibleRange: Bool) {
        let newToday = CalendarDate.today(calendar: calendar)
        let monthChanged = newToday.monthIndex != monthDate.monthIndex || newToday.year != monthDate.year

        todayDate = newToday
        monthDate = newToday
        selectedDate = newToday
        if monthChanged || isInitialVisibleRange {
            refreshVisibleGridRange()
        }
        requestAgendaScroll()
    }

    func goToPreviousMonth() {
        monthNavigationDirection = .backward
        selectDate(selectedDate.addingMonthsPreservingDay(-1, calendar: calendar))
    }

    func goToNextMonth() {
        monthNavigationDirection = .forward
        selectDate(selectedDate.addingMonthsPreservingDay(1, calendar: calendar))
    }

    func selectDate(_ date: CalendarDate) {
        applySelection(date, scrollAgenda: true)
    }

    /// Updates calendar selection from agenda scroll without re-scrolling the agenda.
    func syncSelectionFromAgendaScroll(_ date: CalendarDate) {
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
        guard let first = gridDates.first, let last = gridDates.last else { return }
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
            monthDate = newMonthDate
            refreshVisibleGridRange()
        }
        if scrollAgenda {
            requestAgendaScroll()
        }
    }
}
