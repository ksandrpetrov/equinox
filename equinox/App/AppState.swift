import AppKit
import SwiftUI

@Observable
@MainActor
final class AppState {
    let preferences = PreferencesStore.shared
    let panel = PanelPresentationState()
    let layout = PanelLayoutMetrics()
    let events: EventsCoordinator
    let plaud: PlaudCoordinator

    var calendar: Calendar { events.calendar }

    var isPinned: Bool {
        get { preferences.isPanelPinned }
        set { preferences.isPanelPinned = newValue }
    }

    func togglePinnedState() {
        isPinned.toggle()
        panel.onPinStateChanged?()
    }

    init() {
        let calendar = Calendar.autoupdatingCurrent
        let calendarStore = CalendarStore(calendar: calendar)

        events = EventsCoordinator(
            calendar: calendar,
            calendarStore: calendarStore,
            preferences: preferences
        )

        plaud = PlaudCoordinator(
            preferences: preferences,
            calendar: calendar,
            matchableEvents: { [events] start, end in
                await events.matchableEvents(from: start, to: end)
            },
            eventsByDate: { [events] in events.eventsByDate },
            calendarAccessStatus: { [events] in events.calendarAccessStatus },
            isPlaudEnabled: { [preferences] in preferences.isPlaudEnabled }
        )

        events.registerExternalChangeHandler { [weak self] in
            Task { @MainActor in
                self?.events.retryFetchEvents()
            }
        }

        events.onPlaudDataChanged = { [plaud] in
            plaud.refreshMatchesIfNeeded()
            plaud.matchHistoryIfNeeded()
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

    /// Cross-coordinator action: applies RSVP via `events`, then keeps the detail sheet's
    /// `panel.selectedEvent` pointing at the refreshed event.
    func respondToInvitation(event: DayEvent, status: EventParticipationStatus) async -> String? {
        let result = await events.respondToInvitation(event: event, status: status)
        if result == nil {
            refreshSelectedEvent(matching: event)
        }
        return result
    }

    private func refreshSelectedEvent(matching event: DayEvent) {
        guard let eventID = event.eventIdentifier else { return }
        guard panel.selectedEvent?.eventIdentifier == eventID else { return }
        for dayEvents in events.eventsByDate.values {
            if let updated = dayEvents.first(where: {
                $0.eventIdentifier == eventID && $0.startDate == event.startDate
            }) {
                panel.selectedEvent = updated
                return
            }
        }
    }
}
