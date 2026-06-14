import AppKit
import EventKit
import SwiftUI

@Observable
@MainActor
final class AppState {
    let preferences = PreferencesStore.shared
    let calendar: Calendar
    private let calendarStore: CalendarStore

    var monthDate: CalendarDate
    var selectedDate: CalendarDate
    var todayDate: CalendarDate

    var firstVisibleDate: CalendarDate = CalendarDate(year: 1583, monthIndex: 0, day: 1)
    var lastVisibleDate: CalendarDate = CalendarDate(year: 1583, monthIndex: 0, day: 1)

    var eventsByDate: [CalendarDate: [DayEvent]] = [:]
    var calendarEntries: [CalendarListEntry] = []

    var isPanelVisible = false
    var isPinned: Bool {
        get { preferences.isPanelPinned }
        set { preferences.isPanelPinned = newValue }
    }

    var onPinStateChanged: (() -> Void)?

    func togglePinnedState() {
        isPinned.toggle()
        onPinStateChanged?()
    }

    var isNewEventSheetPresented = false
    var newEventInitialDate: CalendarDate?
    var isGoToDateSheetPresented = false
    var selectedEvent: DayEvent?
    var isEventDetailPresented = false

    var isModalSheetPresented: Bool {
        isNewEventSheetPresented || isGoToDateSheetPresented || isEventDetailPresented
    }

    /// Called when a modal sheet closes so the panel can reclaim focus (unpinned mode).
    var onModalSheetDismissed: (() -> Void)?

    var shouldShowMeetingIndicator = false
    var isFetchingEvents = false
    var calendarAccessStatus: CalendarAccessStatus = .notDetermined
    var lastFetchError: String?
    /// Transient panel-level error message (agenda delete, RSVP failures outside sheets).
    var panelFeedback: String?
    var hasSeenShortcutTip: Bool {
        get { UserDefaults.standard.bool(forKey: kHasSeenShortcutTip) }
        set { UserDefaults.standard.set(newValue, forKey: kHasSeenShortcutTip) }
    }
    /// Upper bound for agenda height; updated by `StatusItemController` when the panel is shown or the screen layout changes.
    var panelAgendaMaxHeight: CGFloat = 400
    var settingsInitialTab: SettingsTab = .general

    private let plaudService = PlaudService()
    private var plaudLinks: [String: PlaudEventMatch] = [:]
    var plaudSetup = PlaudConfigurator.buildSetup()
    private var plaudRefreshTask: Task<Void, Never>?

    private var storeObserver: NSObjectProtocol?

    init() {
        calendar = Calendar.autoupdatingCurrent
        let today = CalendarDate.today(calendar: calendar)
        monthDate = today
        selectedDate = today
        todayDate = today

        calendarStore = CalendarStore(calendar: calendar) {
            NotificationCenter.default.post(name: kEquinoxEventsUpdated, object: nil)
        }

        NotificationCenter.default.addObserver(
            forName: kEquinoxEventsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.syncFromCalendarStore() }
        }

        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.calendarStore.refetchAll() }
        }

        Task { await refreshCalendarAccessStatus() }
    }

    func requestCalendarAccessIfNeeded() {
        Task {
            await calendarStore.requestCalendarAccessIfNeeded()
            await refreshCalendarAccessStatus()
        }
    }

    func refreshCalendarAccessStatus() async {
        calendarAccessStatus = await calendarStore.accessStatus()
    }

    func retryFetchEvents() {
        Task {
            isFetchingEvents = true
            lastFetchError = nil
            await calendarStore.refetchAll()
            isFetchingEvents = false
            lastFetchError = await calendarStore.lastFetchError
            await syncFromCalendarStore()
        }
    }

    var hasSelectedCalendars: Bool {
        !CalendarSelectionStorage.loadSelectedIDs().isEmpty
    }

    func openCalendarPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func syncFromCalendarStore() async {
        eventsByDate = await calendarStore.selectedCalendarEvents()
        calendarEntries = await calendarStore.calendarEntries()
        calendarAccessStatus = await calendarStore.accessStatus()
        lastFetchError = await calendarStore.lastFetchError
        updateMeetingIndicator()
        refreshPlaudMatchesIfNeeded()
    }

    func updateVisibleRange(first: CalendarDate, last: CalendarDate) {
        let range = fetchRange(coveringGridFrom: first, through: last)
        firstVisibleDate = range.first
        lastVisibleDate = range.last
        Task {
            isFetchingEvents = true
            lastFetchError = nil
            await calendarStore.setVisibleRange(first: range.first, last: range.last)
            await calendarStore.fetchEvents()
            isFetchingEvents = false
            lastFetchError = await calendarStore.lastFetchError
            await syncFromCalendarStore()
        }
    }

    func extendFetchRangeForAgendaIfNeeded() {
        let range = fetchRange(coveringGridFrom: firstVisibleDate, through: lastVisibleDate)
        guard range.first != firstVisibleDate || range.last != lastVisibleDate else { return }
        firstVisibleDate = range.first
        lastVisibleDate = range.last
        Task {
            isFetchingEvents = true
            lastFetchError = nil
            await calendarStore.setVisibleRange(first: range.first, last: range.last)
            await calendarStore.fetchEvents()
            isFetchingEvents = false
            lastFetchError = await calendarStore.lastFetchError
            await syncFromCalendarStore()
        }
    }

    func fetchRange(coveringGridFrom gridFirst: CalendarDate, through gridLast: CalendarDate) -> (first: CalendarDate, last: CalendarDate) {
        var fetchFirst = gridFirst
        var fetchLast = gridLast
        let days = preferences.showEventDays
        guard days > 0 else { return (fetchFirst, fetchLast) }
        if selectedDate < fetchFirst {
            fetchFirst = selectedDate
        }
        let agendaLast = selectedDate.addingDays(days - 1)
        if agendaLast > fetchLast {
            fetchLast = agendaLast
        }
        return (fetchFirst, fetchLast)
    }

    func smartDefaultEventDates(for initialDate: CalendarDate? = nil) -> (start: Date, end: Date) {
        EventDraftDefaults.defaultStartAndEnd(
            calendar: calendar,
            initialDate: initialDate ?? newEventInitialDate
        )
    }

    func goToToday() {
        monthDate = todayDate
        selectedDate = todayDate
    }

    func goToPreviousMonth() {
        monthDate = monthDate.addingMonths(-1)
    }

    func goToNextMonth() {
        monthDate = monthDate.addingMonths(1)
    }

    func selectDate(_ date: CalendarDate) {
        selectedDate = date
        if date.monthIndex != monthDate.monthIndex || date.year != monthDate.year {
            monthDate = CalendarDate(year: date.year, monthIndex: date.monthIndex, day: 1)
        }
        extendFetchRangeForAgendaIfNeeded()
    }

    func events(for date: CalendarDate) -> [DayEvent] {
        eventsByDate[date] ?? []
    }

    func makeDotColors(for date: CalendarDate) -> [NSColor]? {
        DayEvent.makeDotColors(for: events(for: date))
    }

    func updateMeetingIndicator() {
        let now = Date()
        let end = calendar.date(byAdding: .minute, value: 30, to: now) ?? now
        var found = false
        for (_, events) in eventsByDate {
            for event in events where !event.isEventAllDay {
                if event.startDate <= end && event.endDate > now, event.joinURL != nil {
                    found = true
                    break
                }
            }
            if found { break }
        }
        shouldShowMeetingIndicator = found
    }

    /// Creates an event. Returns `nil` on success or a localized error message.
    func createEvent(from draft: NewEventDraft) async -> String? {
        do {
            try await calendarStore.createEvent(from: draft)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Deletes an event. Returns `nil` on success or a localized error message.
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
    }

    /// Updates RSVP status. Returns `nil` on success or a localized error message.
    func respondToInvitation(event: DayEvent, status: EventParticipationStatus) async -> String? {
        guard let eventID = event.eventIdentifier else {
            return String(localized: "Could not update response", comment: "RSVP failure title")
        }
        do {
            try await calendarStore.setParticipationStatus(status, for: eventID)
            await syncFromCalendarStore()
            refreshSelectedEvent(matching: event)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func refreshSelectedEvent(matching event: DayEvent) {
        guard let eventID = event.eventIdentifier else { return }
        guard selectedEvent?.eventIdentifier == eventID else { return }
        for events in eventsByDate.values {
            if let updated = events.first(where: {
                $0.eventIdentifier == eventID && $0.startDate == event.startDate
            }) {
                selectedEvent = updated
                return
            }
        }
    }

    func plaudLink(for event: DayEvent) -> PlaudEventMatch? {
        guard preferences.isPlaudEnabled else { return nil }
        guard let eventID = event.eventIdentifier else { return nil }
        let key = PlaudEventMatching.matchKey(eventIdentifier: eventID, startDate: event.startDate)
        return plaudLinks[key]
    }

    func refreshPlaudMatchesIfNeeded(force: Bool = false) {
        guard preferences.isPlaudEnabled else {
            plaudLinks = [:]
            plaudSetup = PlaudConfigurator.buildSetup(enabled: false)
            return
        }

        plaudRefreshTask?.cancel()
        let pastEvents = eventsByDate.values.flatMap { $0 }.filter { $0.endDate < Date() }
        plaudRefreshTask = Task { @MainActor in
            let cached = await plaudService.allCachedLinks()
            guard !Task.isCancelled else { return }
            plaudLinks = cached

            let fresh = await plaudService.refreshMatches(for: pastEvents)
            guard !Task.isCancelled else { return }
            plaudLinks.merge(fresh) { _, new in new }
            plaudSetup = await plaudService.setupStatus()
        }
    }

    func refreshPlaudSetup() async {
        plaudSetup = await plaudService.setupStatus()
    }

    func forceRefreshPlaud() async {
        let pastEvents = eventsByDate.values.flatMap { $0 }.filter { $0.endDate < Date() }
        _ = await plaudService.refreshIfNeeded(force: true)
        plaudLinks = await plaudService.allCachedLinks()
        let fresh = await plaudService.refreshMatches(for: pastEvents)
        plaudLinks.merge(fresh) { _, new in new }
        plaudSetup = await plaudService.setupStatus()
    }

    func saveManualPlaudLink(for event: DayEvent, url: URL) async -> String? {
        do {
            let match = try await plaudService.saveManualLink(for: event, url: url)
            guard let eventID = event.eventIdentifier else { return nil }
            let key = PlaudEventMatching.matchKey(eventIdentifier: eventID, startDate: event.startDate)
            plaudLinks[key] = match
            plaudSetup = await plaudService.setupStatus()
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

extension DayEvent {
    static func makeDotColors(for events: [DayEvent]) -> [NSColor]? {
        guard let colors = makeUniqueCalendarColors(for: events) else { return nil }
        return colors.map(\.calendarColor)
    }

    static func makeSwiftUIDotColors(for events: [DayEvent]) -> [Color]? {
        guard let colors = makeUniqueCalendarColors(for: events) else { return nil }
        return colors.map(\.swiftUIColor)
    }

    private static func makeUniqueCalendarColors(for events: [DayEvent]) -> [DayEvent]? {
        guard !events.isEmpty else { return nil }
        var unique: [DayEvent] = []
        var seen = Set<String>()
        for event in events {
            if seen.insert(event.calendarIdentifier).inserted {
                unique.append(event)
                if unique.count == 3 { break }
            }
        }
        switch unique.count {
        case 0: return nil
        case 1: return [unique[0]]
        case 2: return [unique[0], unique[1]]
        default: return [unique[0], unique[1], unique[2]]
        }
    }
}
