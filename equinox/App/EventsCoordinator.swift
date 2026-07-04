import Foundation

@Observable
@MainActor
final class EventsCoordinator {
    let calendar: Calendar
    private let calendarStore: CalendarStore
    private let preferences: PreferencesStore
    private let fetchCoordinator: EventFetchCoordinator
    var onMeetingIndicatorChanged: () -> Void = {}
    var onPlaudDataChanged: () -> Void = {}
    var isPanelVisible: () -> Bool = { false }

    var monthDate: CalendarDate
    var selectedDate: CalendarDate
    var todayDate: CalendarDate

    var firstVisibleDate: CalendarDate = CalendarDate(year: 1583, monthIndex: 0, day: 1)
    var lastVisibleDate: CalendarDate = CalendarDate(year: 1583, monthIndex: 0, day: 1)

    var eventsByDate: [CalendarDate: [DayEvent]] = [:]
    var calendarEntries: [CalendarListEntry] = []

    var shouldShowMeetingIndicator = false
    var isFetchingEvents = false
    var shouldShowLoadingIndicator = false
    var hasSelectedCalendars = false
    var calendarAccessStatus: CalendarAccessStatus = .notDetermined
    var lastFetchError: String?

    private var agendaVisibleFirst: CalendarDate?
    private var agendaVisibleLast: CalendarDate?
    private var awaitingAgendaFocusAfterFetch = false

    /// Bumped after navigation or panel reopen that should scroll the agenda to `selectedDate`.
    private(set) var agendaScrollToken = 0

    /// Direction of the last month navigation for grid transition animation.
    private(set) var monthNavigationDirection: MonthNavigationDirection = .forward

    enum MonthNavigationDirection {
        case forward
        case backward
    }

    func requestAgendaScroll() {
        agendaScrollToken &+= 1
        if isPanelVisible() {
            awaitingAgendaFocusAfterFetch = true
        }
    }

    init(
        calendar: Calendar,
        calendarStore: CalendarStore,
        preferences: PreferencesStore
    ) {
        self.calendar = calendar
        self.calendarStore = calendarStore
        self.preferences = preferences
        self.fetchCoordinator = EventFetchCoordinator(calendarStore: calendarStore)
        let today = CalendarDate.today(calendar: calendar)
        monthDate = today
        selectedDate = today
        todayDate = today

        fetchCoordinator.onPresentationUpdate = { [weak self] shouldShow, isFetching in
            guard let self else { return }
            self.shouldShowLoadingIndicator = shouldShow
            self.isFetchingEvents = isFetching
        }
        fetchCoordinator.onSyncComplete = { [weak self] in
            await self?.syncFromCalendarStore()
        }
    }

    func registerExternalChangeHandler(_ handler: @escaping @Sendable () -> Void) {
        Task {
            await calendarStore.setExternalChangeHandler(handler)
        }
    }

    func requestCalendarAccessIfNeeded() {
        Task {
            await calendarStore.requestCalendarAccessIfNeeded()
            await syncFromCalendarStore()
        }
    }

    func refreshCalendarAccessStatus() async {
        calendarAccessStatus = await calendarStore.accessStatus()
    }

    func retryFetchEvents() {
        fetchCoordinator.scheduleFetch(
            range: (first: firstVisibleDate, last: lastVisibleDate),
            refetch: true
        )
    }

    func syncFromCalendarStore() async {
        eventsByDate = await calendarStore.selectedCalendarEvents()
        calendarEntries = await calendarStore.calendarEntries()
        calendarAccessStatus = await calendarStore.accessStatus()
        hasSelectedCalendars = await calendarStore.hasSelectedCalendars()
        lastFetchError = await calendarStore.lastFetchError
        updateMeetingIndicator()
        onPlaudDataChanged()
        maybeRefocusAgendaAfterFetch()
    }

    func refreshFetchRange(reason: FetchRangeRefreshReason) {
        switch reason {
        case .visibleGrid(let first, let last):
            applyFetchRange(coveringGridFrom: first, through: last)
        case .agendaBounds:
            applyAgendaFetchExtensionIfNeeded()
        }
    }

    func updateVisibleRange(first: CalendarDate, last: CalendarDate) {
        refreshFetchRange(reason: .visibleGrid(first: first, last: last))
    }

    func updateAgendaVisibleRange(first: CalendarDate, last: CalendarDate) {
        guard first <= last else { return }
        let changed = agendaVisibleFirst != first || agendaVisibleLast != last
        agendaVisibleFirst = first
        agendaVisibleLast = last
        if changed {
            refreshFetchRange(reason: .agendaBounds)
        }
    }

    func fetchRange(coveringGridFrom gridFirst: CalendarDate, through gridLast: CalendarDate) -> (first: CalendarDate, last: CalendarDate) {
        EventFetchRange.range(
            coveringGridFrom: gridFirst,
            through: gridLast,
            agendaFirst: agendaVisibleFirst,
            agendaLast: agendaVisibleLast
        )
    }

    /// Recomputes the visible grid range from `monthDate` + preferences and refreshes the fetch
    /// window. Centralizes the grid range trigger so views only signal intent (navigation, appear,
    /// row-count change) instead of computing ranges themselves.
    func refreshVisibleGridRange() {
        let gridDates = monthGridDates(
            monthDate: monthDate,
            weekStartWeekday: preferences.weekStartWeekday,
            numRows: preferences.calendarRowCount
        )
        guard let first = gridDates.first, let last = gridDates.last else { return }
        updateVisibleRange(first: first, last: last)
    }

    func goToToday() {
        let newToday = CalendarDate.today(calendar: calendar)
        let monthChanged = newToday.monthIndex != monthDate.monthIndex || newToday.year != monthDate.year
        let needsInitialVisibleRange = firstVisibleDate == lastVisibleDate

        todayDate = newToday
        monthDate = newToday
        selectedDate = newToday
        if monthChanged || needsInitialVisibleRange {
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

    func events(for date: CalendarDate) -> [DayEvent] {
        eventsByDate[date] ?? []
    }

    func updateMeetingIndicator() {
        shouldShowMeetingIndicator = MeetingIndicator.shouldShow(
            eventsByDate: eventsByDate,
            now: Date(),
            calendar: calendar
        )
        onMeetingIndicatorChanged()
    }

    func refreshTodayAndMeetingIndicator() {
        let today = CalendarDate.today(calendar: calendar)
        if today != todayDate {
            todayDate = today
        }
        updateMeetingIndicator()
    }

    func createEvent(from draft: NewEventDraft) async -> String? {
        do {
            try await calendarStore.createEvent(from: draft)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func deleteEvent(identifier: String) async -> String? {
        do {
            try await calendarStore.deleteEvent(identifier: identifier)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func updateSelectedCalendar(identifier: String, selected: Bool) async {
        await calendarStore.updateSelectedCalendar(identifier: identifier, selected: selected)
        await syncFromCalendarStore()
    }

    func respondToInvitation(event: DayEvent, status: EventParticipationStatus) async -> String? {
        guard let eventID = event.eventIdentifier else {
            return String(localized: "Could not update response", comment: "RSVP failure title")
        }
        do {
            try await calendarStore.setParticipationStatus(status, for: eventID)
            await syncFromCalendarStore()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func matchableEvents(from start: Date, to end: Date) async -> [DayEvent] {
        await calendarStore.matchableEvents(from: start, to: end)
    }

    private func applyFetchRange(coveringGridFrom gridFirst: CalendarDate, through gridLast: CalendarDate) {
        let range = fetchRange(coveringGridFrom: gridFirst, through: gridLast)
        firstVisibleDate = range.first
        lastVisibleDate = range.last
        fetchCoordinator.scheduleFetch(range: range)
    }

    private func applyAgendaFetchExtensionIfNeeded() {
        let range = fetchRange(coveringGridFrom: firstVisibleDate, through: lastVisibleDate)
        guard range.first != firstVisibleDate || range.last != lastVisibleDate else { return }
        firstVisibleDate = range.first
        lastVisibleDate = range.last
        fetchCoordinator.scheduleFetch(range: range)
    }

    private func maybeRefocusAgendaAfterFetch() {
        guard awaitingAgendaFocusAfterFetch,
              isPanelVisible(),
              selectedDate == todayDate else { return }
        awaitingAgendaFocusAfterFetch = false
        agendaScrollToken &+= 1
    }
}

enum FetchRangeRefreshReason {
    case visibleGrid(first: CalendarDate, last: CalendarDate)
    case agendaBounds
}
