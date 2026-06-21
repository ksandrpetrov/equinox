import EventKit
import Foundation

final class EventKitBridge {
    private let store = EKEventStore()

    private let maxEvents = 500

    func handle(_ data: Data) -> BridgeResponse {
        let command: BridgeCommand
        do {
            command = try JSONDecoder().decode(BridgeCommand.self, from: data)
        } catch {
            return .failure(code: "invalid_request", message: "Invalid JSON command: \(error.localizedDescription)")
        }

        switch command.command {
        case "access_status":
            return accessStatus()
        case "request_access":
            return requestAccess()
        case "list_calendars":
            return listCalendars()
        case "list_events":
            return listEvents(command)
        case "get_event":
            return getEvent(command)
        case "create_event":
            return createEvent(command)
        case "update_event":
            return updateEvent(command)
        case "delete_event":
            return deleteEvent(command)
        default:
            return .failure(code: "unknown_command", message: "Unknown command: \(command.command)")
        }
    }

    private func accessStatus() -> BridgeResponse {
        let status = Self.authorizationStatus()
        return .success(.accessStatus(AccessStatusData(status: status.label, granted: status.granted)))
    }

    private func requestAccess() -> BridgeResponse {
        if Self.authorizationStatus().granted {
            let status = Self.authorizationStatus()
            return .success(.accessRequest(AccessRequestData(granted: true, status: status.label)))
        }

        let semaphore = DispatchSemaphore(value: 0)
        var granted = false
        let handler: EKEventStoreRequestAccessCompletionHandler = { result, _ in
            granted = result
            semaphore.signal()
        }
        store.requestFullAccessToEvents(completion: handler)
        semaphore.wait()

        let status = Self.authorizationStatus()
        return .success(.accessRequest(AccessRequestData(granted: granted && status.granted, status: status.label)))
    }

    private func listCalendars() -> BridgeResponse {
        guard ensureAccess() else { return accessDenied() }

        let calendars = EventKitCalendarMapping.displayableCalendarItems(from: store)
            .compactMap { item -> BridgeCalendar? in
                guard let calendar = store.calendar(withIdentifier: item.id) else { return nil }
                return BridgeCalendar(from: item, calendar: calendar)
            }

        return .success(.calendars(CalendarsData(calendars: calendars)))
    }

    private func listEvents(_ command: BridgeCommand) -> BridgeResponse {
        guard ensureAccess() else { return accessDenied() }

        guard let startDateString = command.startDate, let endDateString = command.endDate else {
            return .failure(code: "invalid_request", message: "startDate and endDate are required")
        }
        guard let rangeStart = BridgeDateParsing.parseDateBoundary(startDateString, endOfDay: false),
              let rangeEnd = BridgeDateParsing.parseDateBoundary(endDateString, endOfDay: true) else {
            return .failure(code: "invalid_request", message: "Invalid date range")
        }
        if rangeEnd < rangeStart {
            return .failure(code: "invalid_request", message: "endDate must be on or after startDate")
        }

        let calendars: [EKCalendar]
        if let calendarIds = command.calendarIds, !calendarIds.isEmpty {
            calendars = calendarIds.compactMap { store.calendar(withIdentifier: $0) }
        } else {
            calendars = EventKitCalendarMapping.displayableCalendars(from: store)
        }

        let predicate = store.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: calendars)
        let ekEvents = store.events(matching: predicate)
            .filter { !isDeclined($0) }
            .sorted { $0.startDate < $1.startDate }

        let limit = min(command.limit ?? maxEvents, maxEvents)
        let truncated = ekEvents.count > limit
        let selected = Array(ekEvents.prefix(limit))
        let events = selected.map(mapEvent)

        return .success(.events(EventsData(events: events, truncated: truncated)))
    }

    private func getEvent(_ command: BridgeCommand) -> BridgeResponse {
        guard ensureAccess() else { return accessDenied() }

        guard let identifier = command.eventIdentifier, !identifier.isEmpty else {
            return .failure(code: "invalid_request", message: "eventIdentifier is required")
        }
        guard let event = store.event(withIdentifier: identifier) else {
            return .failure(code: "not_found", message: "Event not found")
        }
        if isDeclined(event) {
            return .failure(code: "not_found", message: "Event not found")
        }

        return .success(.event(EventData(event: mapEvent(event))))
    }

    private func createEvent(_ command: BridgeCommand) -> BridgeResponse {
        guard ensureAccess() else { return accessDenied() }

        guard let title = command.title, !title.isEmpty else {
            return .failure(code: "invalid_request", message: "title is required")
        }
        guard let start = BridgeDateParsing.parseInstant(command.startDate) else {
            return .failure(code: "invalid_request", message: "startDate is required")
        }
        guard let end = BridgeDateParsing.parseInstant(command.endDate) else {
            return .failure(code: "invalid_request", message: "endDate is required")
        }

        let calendar: EKCalendar
        if let calendarId = command.calendarId, let resolved = store.calendar(withIdentifier: calendarId) {
            calendar = resolved
        } else if let defaultCalendar = store.defaultCalendarForNewEvents {
            calendar = defaultCalendar
        } else {
            return .failure(code: "invalid_request", message: "calendarId is required when no default calendar exists")
        }
        guard calendar.allowsContentModifications else {
            return .failure(code: "read_only_calendar", message: "Calendar does not allow modifications")
        }

        let event = EKEvent(eventStore: store)
        EventKitMutation.applyBridgeCreate(
            title: title,
            start: start,
            end: end,
            calendar: calendar,
            allDay: command.allDay ?? false,
            location: command.location,
            notes: command.notes,
            url: command.url.flatMap { URL(string: $0) },
            to: event
        )

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            return .failure(code: "save_failed", message: error.localizedDescription)
        }

        return .success(.mutation(MutationData(
            eventIdentifier: event.eventIdentifier,
            calendarItemIdentifier: event.calendarItemIdentifier
        )))
    }

    private func updateEvent(_ command: BridgeCommand) -> BridgeResponse {
        guard ensureAccess() else { return accessDenied() }

        guard let identifier = command.eventIdentifier, !identifier.isEmpty else {
            return .failure(code: "invalid_request", message: "eventIdentifier is required")
        }
        guard let event = store.event(withIdentifier: identifier) else {
            return .failure(code: "not_found", message: "Event not found")
        }
        if isDeclined(event) {
            return .failure(code: "not_found", message: "Event not found")
        }
        guard event.calendar.allowsContentModifications else {
            return .failure(code: "read_only_calendar", message: "Event calendar does not allow modifications")
        }

        var targetCalendar: EKCalendar?
        if let calendarId = command.calendarId, let calendar = store.calendar(withIdentifier: calendarId) {
            guard calendar.allowsContentModifications else {
                return .failure(code: "read_only_calendar", message: "Target calendar does not allow modifications")
            }
            targetCalendar = calendar
        }

        EventKitMutation.applyBridgeUpdate(
            title: command.title,
            start: BridgeDateParsing.parseInstant(command.startDate),
            end: BridgeDateParsing.parseInstant(command.endDate),
            allDay: command.allDay,
            location: command.location,
            notes: command.notes,
            url: command.url.flatMap { URL(string: $0) },
            calendar: targetCalendar,
            to: event
        )

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            return .failure(code: "save_failed", message: error.localizedDescription)
        }

        return .success(.mutation(MutationData(
            eventIdentifier: event.eventIdentifier,
            calendarItemIdentifier: event.calendarItemIdentifier
        )))
    }

    private func deleteEvent(_ command: BridgeCommand) -> BridgeResponse {
        guard ensureAccess() else { return accessDenied() }

        guard let identifier = command.eventIdentifier, !identifier.isEmpty else {
            return .failure(code: "invalid_request", message: "eventIdentifier is required")
        }
        guard let event = store.event(withIdentifier: identifier) else {
            return .failure(code: "not_found", message: "Event not found")
        }
        if isDeclined(event) {
            return .failure(code: "not_found", message: "Event not found")
        }
        guard event.calendar.allowsContentModifications else {
            return .failure(code: "read_only_calendar", message: "Event calendar does not allow modifications")
        }

        let span: EKSpan
        switch command.span {
        case "futureEvents":
            span = .futureEvents
        default:
            span = .thisEvent
        }

        do {
            try store.remove(event, span: span, commit: true)
        } catch {
            return .failure(code: "delete_failed", message: error.localizedDescription)
        }

        return .success(.mutation(MutationData(eventIdentifier: identifier, calendarItemIdentifier: nil)))
    }

    // MARK: - Helpers

    private func ensureAccess() -> Bool {
        Self.authorizationStatus().granted
    }

    private func accessDenied() -> BridgeResponse {
        .failure(code: "access_denied", message: "Calendar access not granted. Run request_access first.")
    }

    private static func authorizationStatus() -> (label: String, granted: Bool) {
        CalendarAccessMapping.bridgeAuthorizationStatus()
    }

    private func isDeclined(_ event: EKEvent) -> Bool {
        EventParticipationMapping.isDeclinedParticipation(
            hasAttendees: event.hasAttendees,
            eventKitRawValue: event.equinoxParticipationRawValue
        )
    }

    private func mapEvent(_ event: EKEvent) -> BridgeEvent {
        BridgeEventMapping.bridgeEvent(from: event)
    }

}
