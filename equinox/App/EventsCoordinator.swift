import Foundation

@Observable
@MainActor
final class EventsCoordinator {
    let calendar: Calendar
    private let calendarStore: CalendarStore
    private let preferences: PreferencesStore
    var onMeetingIndicatorChanged: () -> Void = {}
    var onPlaudDataChanged: () -> Void = {}

    var monthDate: CalendarDate
    var selectedDate: CalendarDate
    var todayDate: CalendarDate

    var firstVisibleDate: CalendarDate = CalendarDate(year: 1583, monthIndex: 0, day: 1)
    var lastVisibleDate: CalendarDate = CalendarDate(year: 1583, monthIndex: 0, day: 1)

    var eventsByDate: [CalendarDate: [DayEvent]] = [:]
    var calendarEntries: [CalendarListEntry] = []

    var shouldShowMeetingIndicator = false
    var isFetchingEvents = false
    var hasSelectedCalendars = false
    var calendarAccessStatus: CalendarAccessStatus = .notDetermined
    var lastFetchError: String?

    /// Bumped after navigation that should scroll the agenda to `selectedDate`.
    private(set) var agendaScrollToken = 0

    init(
        calendar: Calendar,
        calendarStore: CalendarStore,
        preferences: PreferencesStore
    ) {
        self.calendar = calendar
        self.calendarStore = calendarStore
        self.preferences = preferences
        let today = CalendarDate.today(calendar: calendar)
        monthDate = today
        selectedDate = today
        todayDate = today
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
        Task {
            await performFetch {
                await calendarStore.refetchAll()
            }
        }
    }

    func syncFromCalendarStore() async {
        eventsByDate = await calendarStore.selectedCalendarEvents()
        calendarEntries = await calendarStore.calendarEntries()
        calendarAccessStatus = await calendarStore.accessStatus()
        hasSelectedCalendars = await calendarStore.hasSelectedCalendars()
        lastFetchError = await calendarStore.lastFetchError
        isFetchingEvents = await calendarStore.isFetchingEvents
        updateMeetingIndicator()
        onPlaudDataChanged()
    }

    func refreshFetchRange(reason: FetchRangeRefreshReason) {
        switch reason {
        case .visibleGrid(let first, let last):
            applyFetchRange(coveringGridFrom: first, through: last)
        case .agendaExtension:
            applyAgendaFetchExtensionIfNeeded()
        }
    }

    func updateVisibleRange(first: CalendarDate, last: CalendarDate) {
        refreshFetchRange(reason: .visibleGrid(first: first, last: last))
    }

    func extendFetchRangeForAgendaIfNeeded() {
        refreshFetchRange(reason: .agendaExtension)
    }

    func fetchRange(coveringGridFrom gridFirst: CalendarDate, through gridLast: CalendarDate) -> (first: CalendarDate, last: CalendarDate) {
        EventFetchRange.range(
            coveringGridFrom: gridFirst,
            through: gridLast,
            selectedDate: selectedDate,
            agendaDays: preferences.showEventDays
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
        todayDate = CalendarDate.today(calendar: calendar)
        monthDate = todayDate
        selectedDate = todayDate
        refreshVisibleGridRange()
        requestAgendaScroll()
    }

    func goToPreviousMonth() {
        monthDate = monthDate.addingMonths(-1)
        refreshVisibleGridRange()
    }

    func goToNextMonth() {
        monthDate = monthDate.addingMonths(1)
        refreshVisibleGridRange()
    }

    func selectDate(_ date: CalendarDate) {
        selectedDate = date
        if date.monthIndex != monthDate.monthIndex || date.year != monthDate.year {
            monthDate = CalendarDate(year: date.year, monthIndex: date.monthIndex, day: 1)
            refreshVisibleGridRange()
        } else {
            extendFetchRangeForAgendaIfNeeded()
        }
        requestAgendaScroll()
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
        Task {
            await performFetch {
                await calendarStore.setVisibleRange(first: range.first, last: range.last)
                await calendarStore.fetchEvents()
            }
        }
    }

    private func applyAgendaFetchExtensionIfNeeded() {
        let range = fetchRange(coveringGridFrom: firstVisibleDate, through: lastVisibleDate)
        guard range.first != firstVisibleDate || range.last != lastVisibleDate else { return }
        firstVisibleDate = range.first
        lastVisibleDate = range.last
        Task {
            await performFetch {
                await calendarStore.setVisibleRange(first: range.first, last: range.last)
                await calendarStore.fetchEvents()
            }
        }
    }

    private func requestAgendaScroll() {
        agendaScrollToken &+= 1
    }

    private func performFetch(_ operation: () async -> Void) async {
        lastFetchError = nil
        await operation()
        isFetchingEvents = await calendarStore.isFetchingEvents
        lastFetchError = await calendarStore.lastFetchError
        await syncFromCalendarStore()
    }
}

enum FetchRangeRefreshReason {
    case visibleGrid(first: CalendarDate, last: CalendarDate)
    case agendaExtension
}
