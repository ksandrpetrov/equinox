import Foundation

@Observable
@MainActor
final class EventsCoordinator {
    let calendar: Calendar
    private let calendarStore: CalendarStore
    private let preferences: PreferencesStore
    private let fetchCoordinator: EventFetchCoordinator
    private let navigation: CalendarNavigationCoordinator

    var onMeetingIndicatorChanged: () -> Void = {}
    var onPlaudDataChanged: () -> Void = {}
    var isPanelVisible: () -> Bool = { false } {
        didSet { navigation.isPanelVisible = isPanelVisible }
    }

    var monthDate: CalendarDate {
        get { navigation.monthDate }
        set { navigation.monthDate = newValue }
    }

    var selectedDate: CalendarDate {
        get { navigation.selectedDate }
        set { navigation.selectedDate = newValue }
    }

    var todayDate: CalendarDate {
        get { navigation.todayDate }
        set { navigation.todayDate = newValue }
    }

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

    var agendaScrollToken: Int { navigation.agendaScrollToken }
    var monthNavigationDirection: CalendarNavigationCoordinator.MonthNavigationDirection {
        navigation.monthNavigationDirection
    }

    var visibleGridDates: [CalendarDate] {
        navigation.visibleGridDates
    }

    private var agendaVisibleFirst: CalendarDate?
    private var agendaVisibleLast: CalendarDate?

    init(
        calendar: Calendar,
        calendarStore: CalendarStore,
        preferences: PreferencesStore
    ) {
        self.calendar = calendar
        self.calendarStore = calendarStore
        self.preferences = preferences
        self.fetchCoordinator = EventFetchCoordinator(calendarStore: calendarStore)
        self.navigation = CalendarNavigationCoordinator(calendar: calendar, preferences: preferences)

        navigation.onVisibleGridRangeChanged = { [weak self] first, last in
            self?.updateVisibleRange(first: first, last: last)
        }

        fetchCoordinator.onPresentationUpdate = { [weak self] shouldShow, isFetching in
            guard let self else { return }
            self.shouldShowLoadingIndicator = shouldShow
            self.isFetchingEvents = isFetching
        }
        fetchCoordinator.onSyncComplete = { [weak self] in
            await self?.syncFromCalendarStore()
        }

        preferences.onVisibleGridPreferencesChanged = { [weak self] in
            self?.refreshVisibleGridRange()
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

    func refreshVisibleGridRange() {
        navigation.refreshVisibleGridRange()
    }

    func requestAgendaScroll() {
        navigation.requestAgendaScroll()
    }

    func goToToday() {
        navigation.goToToday(isInitialVisibleRange: firstVisibleDate == lastVisibleDate)
    }

    func goToPreviousMonth() {
        navigation.goToPreviousMonth()
    }

    func goToNextMonth() {
        navigation.goToNextMonth()
    }

    func selectDate(_ date: CalendarDate) {
        navigation.selectDate(date)
    }

    func syncSelectionFromAgendaScroll(_ date: CalendarDate) {
        navigation.syncSelectionFromAgendaScroll(date)
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
        navigation.refreshTodayIfNeeded()
        updateMeetingIndicator()
    }

    func createEvent(from draft: NewEventDraft) async -> String? {
        do {
            try await calendarStore.createEvent(from: draft)
            await syncFromCalendarStore()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func deleteEvent(identifier: String) async -> String? {
        do {
            try await calendarStore.deleteEvent(identifier: identifier)
            await syncFromCalendarStore()
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
        guard navigation.awaitingAgendaFocusAfterFetch,
              isPanelVisible(),
              selectedDate == todayDate else { return }
        navigation.clearAwaitingAgendaFocusAfterFetch()
        navigation.requestAgendaScroll()
    }
}

enum FetchRangeRefreshReason {
    case visibleGrid(first: CalendarDate, last: CalendarDate)
    case agendaBounds
}
