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
    let preferences = PreferencesStore.shared
    let panel = PanelPresentationState()
    let layout = PanelLayoutMetrics()
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
        UserDefaults.standard.set(false, forKey: kPinnedPanelVisible)
        KeyboardShortcuts.reset(.togglePanel)
        if wasPinned != isPinned {
            panel.onPinStateChanged?()
        }
        await events.resetCalendarSelection()
        do {
            try LaunchAtLogin.setEnabled(false)
            return nil
        } catch {
            return String(
                format: String(localized: "Could not update Launch at Login: %@", comment: "Launch at login error"),
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
        events.requestAgendaScroll()
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
    var onRequestPresentPanel: ((Bool) -> Void)?

    /// Navigates the calendar to `date` and optionally presents the panel (`resetToToday: false`).
    func navigateToDate(_ date: Date, presentPanel: Bool = true) {
        let calendarDate = CalendarDate(date: date, calendar: calendar)
        events.selectDate(calendarDate)
        if presentPanel {
            onRequestPresentPanel?(false)
        }
    }

    /// Parses `yyyy-MM-dd` deep-link paths and navigates to that day.
    func navigateToDeepLinkDateString(_ dateString: String, presentPanel: Bool = true) -> Bool {
        guard let calendarDate = CalendarDateParsing.parseDayString(dateString) else {
            return false
        }
        events.selectDate(calendarDate)
        if presentPanel {
            onRequestPresentPanel?(false)
        }
        return true
    }

    init() {
        let calendar = Calendar.equinoxGregorian()
        let calendarStore = CalendarStore(calendar: calendar)

        events = EventsCoordinator(
            calendar: calendar,
            calendarStore: calendarStore,
            preferences: preferences
        )

        events.registerExternalChangeHandler { [weak self] in
            Task { @MainActor in
                self?.events.retryFetchEvents()
            }
        }

        events.isPanelVisible = { [weak self] in
            self?.panel.isPanelVisible == true
        }

        events.onEventsSnapshotChanged = { [weak self] in
            self?.refreshSelectedEventFromSnapshot()
        }

        Task { await events.refreshCalendarAccessStatus() }
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
