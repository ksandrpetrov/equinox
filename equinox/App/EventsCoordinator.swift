import Foundation

@Observable
@MainActor
final class EventsCoordinator {
    let calendar: Calendar
    private let calendarStore: any CalendarEventStore
    private let preferences: PreferencesStore
    private let fetchCoordinator: EventFetchCoordinator
    private let navigation: CalendarNavigationCoordinator

    var onMeetingIndicatorChanged: () -> Void = {}
    var onEventsSnapshotChanged: () -> Void = {}
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

    var eventsByDate: [CalendarDate: [DayEvent]] = [:]
    var calendarEntries: [CalendarListEntry] = []
    var defaultCalendarIdentifierForNewEvents: String?
    var currentTime = Date()

    var shouldShowMeetingIndicator = false
    var isFetchingEvents = false
    var shouldShowLoadingIndicator = false
    var hasSelectedCalendars = false
    var calendarAccessStatus: CalendarAccessStatus = .notDetermined
    var lastFetchError: String?
    var hasCompletedInitialEventLoad = false

    var agendaScrollToken: Int { navigation.agendaScrollToken }
    var agendaFocusesDayStart: Bool { navigation.agendaFocusesDayStart }
    var canGoToPreviousMonth: Bool { navigation.canGoToPreviousMonth }
    var canGoToNextMonth: Bool { navigation.canGoToNextMonth }
    var hasCalendars: Bool {
        calendarEntries.contains { entry in
            if case .calendar = entry { return true }
            return false
        }
    }

    var visibleGridDates: [CalendarDate] {
        navigation.visibleGridDates
    }

    private var snapshotGeneration = 0

    private var agendaVisibleFirst: CalendarDate?
    private var agendaVisibleLast: CalendarDate?
    private var visibleGridRange: (first: CalendarDate, last: CalendarDate)?
    private var currentFetchRange: (first: CalendarDate, last: CalendarDate)?

    init(
        calendar: Calendar,
        calendarStore: any CalendarEventStore,
        preferences: PreferencesStore
    ) {
        self.calendar = calendar
        self.calendarStore = calendarStore
        self.preferences = preferences
        self.fetchCoordinator = EventFetchCoordinator(calendarStore: calendarStore)
        self.navigation = CalendarNavigationCoordinator(calendar: calendar, preferences: preferences)

        navigation.onVisibleGridRangeChanged = { [weak self] first, last in
            self?.reanchorAgendaRangeForCurrentSelectionIfNeeded()
            self?.updateVisibleRange(first: first, last: last)
        }

        fetchCoordinator.onPresentationUpdate = { [weak self] shouldShow, isFetching in
            guard let self else { return }
            self.shouldShowLoadingIndicator = shouldShow
            self.isFetchingEvents = isFetching
        }
        fetchCoordinator.onSyncComplete = { [weak self] successfulFetch in
            guard let self else { return }
            await self.syncFromCalendarStore()
            if successfulFetch, self.calendarAccessStatus.isAuthorized,
               self.hasCompletedInitialEventLoad, self.lastFetchError == nil {
                self.navigation.refocusAgendaAfterFetch()
            }
        }

        preferences.onVisibleGridPreferencesChanged = { [weak self] in
            self?.refreshVisibleGridRange()
        }
    }

    func requestCalendarAccessIfNeeded() {
        let range = updateCurrentFetchRange()
        Task {
            _ = await fetchCoordinator.fetch(
                range: range,
                refetch: true,
                preparesCalendarAccess: true
            )
        }
    }

    func refreshCalendarAccessStatus() async {
        await syncFromCalendarStore()
    }

    func retryFetchEvents() {
        let range = updateCurrentFetchRange()
        fetchCoordinator.scheduleFetch(
            range: range,
            refetch: true
        )
    }

    func syncFromCalendarStore() async {
        snapshotGeneration &+= 1
        let generation = snapshotGeneration
        let snapshot = await calendarStore.snapshot()
        guard generation == snapshotGeneration else { return }
        calendarAccessStatus = snapshot.accessStatus
        eventsByDate = snapshot.eventsByDate
        calendarEntries = snapshot.calendarEntries
        defaultCalendarIdentifierForNewEvents = snapshot.defaultCalendarIdentifier
        hasSelectedCalendars = snapshot.hasSelectedCalendars
        hasCompletedInitialEventLoad = snapshot.hasCompletedInitialLoad
        lastFetchError = snapshot.lastFetchError
        updateMeetingIndicator()
        onEventsSnapshotChanged()
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
            agendaFirst: preferences.showsAgenda ? agendaVisibleFirst : nil,
            agendaLast: preferences.showsAgenda ? agendaVisibleLast : nil
        )
    }

    func refreshVisibleGridRange() {
        navigation.refreshVisibleGridRange()
    }

    func refreshForPanelPresentation() {
        fetchCoordinator.scheduleFetch(
            range: updateCurrentFetchRange(),
            refetch: true
        )
    }

    func goToToday() {
        navigation.goToToday(isInitialVisibleRange: visibleGridRange == nil)
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

    func updateMeetingIndicator(now: Date = Date()) {
        shouldShowMeetingIndicator = MeetingIndicator.shouldShow(
            eventsByDate: eventsByDate,
            now: now,
            calendar: calendar
        )
        onMeetingIndicatorChanged()
    }

    func refreshTodayAndMeetingIndicator() {
        currentTime = Date()
        let previousToday = navigation.todayDate
        navigation.refreshTodayIfNeeded()
        if navigation.todayDate != previousToday {
            retryFetchEvents()
        }
        updateMeetingIndicator(now: currentTime)
    }

    func refreshAfterSignificantTimeChange() {
        currentTime = Date()
        navigation.refreshTodayIfNeeded()
        Task {
            await calendarStore.invalidateTimeContext()
            await syncFromCalendarStore()
            retryFetchEvents()
        }
        updateMeetingIndicator(now: currentTime)
    }

    func createEvent(from draft: NewEventDraft) async -> String? {
        do {
            try await calendarStore.createEvent(from: draft)
            selectDate(CalendarDate(date: draft.startDate, calendar: calendar))
            _ = await reloadCurrentEvents()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func deleteEvent(identifier: String, occurrenceStartDate: Date) async -> String? {
        do {
            try await calendarStore.deleteEvent(
                identifier: identifier,
                occurrenceStartDate: occurrenceStartDate
            )
            _ = await reloadCurrentEvents()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func updateSelectedCalendar(identifier: String, selected: Bool) async {
        await calendarStore.updateSelectedCalendar(identifier: identifier, selected: selected)
        await syncFromCalendarStore()
        _ = await reloadCurrentEvents()
    }

    func resetCalendarSelection() async {
        await calendarStore.resetCalendarSelection()
        _ = await reloadCurrentEvents()
    }

    private func applyFetchRange(coveringGridFrom gridFirst: CalendarDate, through gridLast: CalendarDate) {
        visibleGridRange = (gridFirst, gridLast)
        let range = fetchRange(coveringGridFrom: gridFirst, through: gridLast)
        currentFetchRange = range
        fetchCoordinator.scheduleNavigationFetch(range: range)
    }

    private func applyAgendaFetchExtensionIfNeeded() {
        guard let visibleGridRange else { return }
        let range = fetchRange(
            coveringGridFrom: visibleGridRange.first,
            through: visibleGridRange.last
        )
        guard !sameRange(range, currentFetchRange) else { return }
        currentFetchRange = range
        fetchCoordinator.scheduleFetch(range: range)
    }

    private func reloadCurrentEvents() async -> Bool {
        await fetchCoordinator.fetch(
            range: updateCurrentFetchRange(),
            refetch: true
        )
    }

    private func updateCurrentFetchRange() -> (first: CalendarDate, last: CalendarDate) {
        reanchorAgendaRangeForCurrentSelectionIfNeeded()
        guard let rawGridFirst = visibleGridDates.first,
              let rawGridLast = visibleGridDates.last else {
            return currentFetchRange ?? (
                CalendarDate.minimumSupported,
                CalendarDate.minimumSupported
            )
        }
        let gridFirst = max(rawGridFirst, CalendarDate.minimumSupported)
        let gridLast = min(rawGridLast, CalendarDate.maximumSupported)
        visibleGridRange = (gridFirst, gridLast)
        let range = fetchRange(coveringGridFrom: gridFirst, through: gridLast)
        currentFetchRange = range
        return range
    }

    private func reanchorAgendaRangeForCurrentSelectionIfNeeded() {
        guard let agendaVisibleFirst, let agendaVisibleLast else { return }
        let adjusted = AgendaDisplayRange.rangeCovering(
            date: navigation.selectedDate,
            first: agendaVisibleFirst,
            last: agendaVisibleLast
        )
        self.agendaVisibleFirst = adjusted.first
        self.agendaVisibleLast = adjusted.last
    }

    private func sameRange(
        _ lhs: (first: CalendarDate, last: CalendarDate),
        _ rhs: (first: CalendarDate, last: CalendarDate)?
    ) -> Bool {
        lhs.first == rhs?.first && lhs.last == rhs?.last
    }

}

enum FetchRangeRefreshReason {
    case visibleGrid(first: CalendarDate, last: CalendarDate)
    case agendaBounds
}
