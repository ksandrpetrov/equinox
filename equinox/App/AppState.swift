import AppKit
import KeyboardShortcuts
import SwiftUI

/// Composition root for the menu bar panel.
/// - Mutations (create/delete/calendar access) → call facade methods on `AppState`.
/// - Reads and SwiftUI bindings (`monthDate`, `eventsByDate`, loading flags) → `appState.events`,
///   or `appState.panel` coordinators directly (`@Observable` pattern).
@Observable
@MainActor
final class AppState {
    private let resetShortcuts: () -> Void
    private let disableLaunchAtLogin: () throws -> Void
    let preferences: PreferencesStore
    let panel = PanelPresentationState()
    let layout = PanelLayoutMetrics()
    private var initialization: Task<Void, Never>?
    let events: EventsCoordinator

    var calendar: Calendar { events.calendar }

    var isPinned: Bool {
        get { preferences.isPanelPinned }
        set { preferences.isPanelPinned = newValue }
    }

    func togglePinnedState() {
        isPinned.toggle()
        panel.onPinStateChanged?()
    }

    func setPinned(_ pinned: Bool) {
        guard isPinned != pinned else { return }
        isPinned = pinned
        panel.onPinStateChanged?()
    }

    func goToPreviousMonth() {
        events.goToPreviousMonth()
    }

    func goToNextMonth() {
        events.goToNextMonth()
    }

    func requestCalendarAccessIfNeeded() {
        events.requestCalendarAccessIfNeeded()
    }

    func refreshCalendarAccessStatus() async {
        await events.refreshCalendarAccessStatus()
    }

    func updateSelectedCalendar(identifier: String, selected: Bool) async {
        await events.updateSelectedCalendar(identifier: identifier, selected: selected)
    }

    func resetPreferencesToDefaults() async -> String? {
        let wasPinned = isPinned
        preferences.resetToDefaults()
        resetShortcuts()
        if wasPinned != isPinned {
            panel.onPinStateChanged?()
        }
        await events.resetCalendarSelection()
        do {
            try disableLaunchAtLogin()
            return nil
        } catch {
            return String(
                format: String(localized: "Could not update Launch at Login: %@", bundle: .equinox, comment: "Launch at login error"),
                error.localizedDescription
            )
        }
    }

    func selectDate(_ date: CalendarDate) {
        events.selectDate(date)
    }

    func goToToday() {
        events.goToToday()
    }

    func panelDidOpen() {
        events.refreshForPanelPresentation()
    }

    func createEvent(from draft: NewEventDraft) async -> String? {
        await events.createEvent(from: draft)
    }

    func deleteEvent(identifier: String, occurrenceStartDate: Date) async -> String? {
        let result = await events.deleteEvent(
            identifier: identifier,
            occurrenceStartDate: occurrenceStartDate
        )
        if result == nil {
            clearSelectedEventIfDeleted(
                identifier: identifier,
                occurrenceStartDate: occurrenceStartDate
            )
        }
        return result
    }

    private func clearSelectedEventIfDeleted(identifier: String, occurrenceStartDate: Date) {
        if panel.selectedEvent?.eventIdentifier == identifier,
           panel.selectedEvent?.startDate == occurrenceStartDate {
            panel.isEventDetailPresented = false
            panel.selectedEvent = nil
        }
    }

    /// Presents the menu bar panel when set by `StatusItemController` during setup.
    var onRequestPresentPanel: (() -> Void)?

    /// Navigates the calendar to `date` and optionally presents the panel.
    func navigateToDate(_ date: Date, presentPanel: Bool = true) {
        let calendarDate = CalendarDate(date: date, calendar: calendar)
        events.selectDate(calendarDate)
        if presentPanel {
            onRequestPresentPanel?()
        }
    }

    /// Parses `yyyy-MM-dd` deep-link paths and navigates to that day.
    func navigateToDeepLinkDateString(_ dateString: String, presentPanel: Bool = true) -> Bool {
        guard let calendarDate = CalendarDateParsing.parseDayString(dateString) else {
            return false
        }
        events.selectDate(calendarDate)
        if presentPanel {
            onRequestPresentPanel?()
        }
        return true
    }

    convenience init() {
        let calendar = Calendar.equinoxGregorian()
        self.init(calendar: calendar, calendarStore: CalendarStore(calendar: calendar), preferences: .shared)
    }

    init(
        calendar: Calendar,
        calendarStore: any CalendarEventStore,
        preferences: PreferencesStore,
        resetShortcuts: @escaping () -> Void = { KeyboardShortcuts.reset(.togglePanel) },
        disableLaunchAtLogin: @escaping () throws -> Void = { try LaunchAtLogin.setEnabled(false) }
    ) {
        self.resetShortcuts = resetShortcuts
        self.disableLaunchAtLogin = disableLaunchAtLogin
        self.preferences = preferences

        events = EventsCoordinator(
            calendar: calendar,
            calendarStore: calendarStore,
            preferences: preferences
        )

        events.isPanelVisible = { [weak self] in
            self?.panel.isPanelVisible == true
        }

        events.onEventsSnapshotChanged = { [weak self] in
            self?.refreshSelectedEventFromSnapshot()
        }

        initialization = Task { [weak self, events] in
            await calendarStore.setExternalChangeHandler { [weak self] in
                Task { @MainActor in self?.events.retryFetchEvents() }
            }
            await events.refreshCalendarAccessStatus()
        }
    }

    func waitForInitialization() async {
        await initialization?.value
    }

    func openCalendarPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func smartDefaultEventDates(for initialDate: CalendarDate? = nil) -> (start: Date, end: Date) {
        EventDraftDefaults.defaultStartAndEnd(
            calendar: calendar,
            initialDate: initialDate ?? panel.newEventInitialDate
        )
    }

    private func refreshSelectedEventFromSnapshot() {
        guard let selectedEvent = panel.selectedEvent else { return }
        // Time-context invalidation clears the cache before its replacement arrives.
        // An incomplete authorized snapshot cannot establish that an event was deleted.
        if events.calendarAccessStatus.isAuthorized,
           events.hasSelectedCalendars,
           !events.hasCompletedInitialEventLoad {
            return
        }
        let refreshedEvent = events.eventsByDate.values
            .lazy
            .joined()
            .first { $0.representsSameOccurrence(as: selectedEvent) }
        if let refreshedEvent {
            panel.selectedEvent = refreshedEvent
        } else {
            panel.isEventDetailPresented = false
            panel.selectedEvent = nil
        }
    }

}
