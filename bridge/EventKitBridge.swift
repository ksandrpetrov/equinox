import EventKit
import Foundation

final class EventKitBridge {
    private let store = EKEventStore()
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let isoFormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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

        let calendars = CalendarListing.filterDisplayableCalendars(
            CalendarListing.sortCalendarsForDisplay(
                store.calendars(for: .event).map(mapCalendarListItem)
            )
        ).compactMap { item -> BridgeCalendar? in
            guard let calendar = store.calendar(withIdentifier: item.id) else { return nil }
            return mapCalendar(calendar)
        }

        return .success(.calendars(CalendarsData(calendars: calendars)))
    }

    private func listEvents(_ command: BridgeCommand) -> BridgeResponse {
        guard ensureAccess() else { return accessDenied() }

        guard let startDateString = command.startDate, let endDateString = command.endDate else {
            return .failure(code: "invalid_request", message: "startDate and endDate are required")
        }
        guard let rangeStart = parseDateBoundary(startDateString, endOfDay: false),
              let rangeEnd = parseDateBoundary(endDateString, endOfDay: true) else {
            return .failure(code: "invalid_request", message: "Invalid date range")
        }
        if rangeEnd < rangeStart {
            return .failure(code: "invalid_request", message: "endDate must be on or after startDate")
        }

        let calendars: [EKCalendar]
        if let calendarIds = command.calendarIds, !calendarIds.isEmpty {
            calendars = calendarIds.compactMap { store.calendar(withIdentifier: $0) }
        } else {
            calendars = CalendarListing.filterDisplayableCalendars(
                CalendarListing.sortCalendarsForDisplay(
                    store.calendars(for: .event).map(mapCalendarListItem)
                )
            ).compactMap { store.calendar(withIdentifier: $0.id) }
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
        guard let start = parseInstant(command.startDate) else {
            return .failure(code: "invalid_request", message: "startDate is required")
        }
        guard let end = parseInstant(command.endDate) else {
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
            start: parseInstant(command.startDate),
            end: parseInstant(command.endDate),
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

    private func mapCalendarListItem(_ calendar: EKCalendar) -> CalendarListItem {
        EventKitCalendarMapping.calendarListItem(from: calendar)
    }

    private func mapCalendar(_ calendar: EKCalendar) -> BridgeCalendar {
        let item = EventKitCalendarMapping.calendarListItem(from: calendar)
        return BridgeCalendar(
            id: item.id,
            title: item.title,
            sourceTitle: item.sourceTitle,
            sourceIdentifier: item.sourceIdentifier,
            colorHex: EventKitCalendarMapping.colorHexOrGray(calendar.color),
            allowsContentModifications: calendar.allowsContentModifications,
            isSubscribed: calendar.isSubscribed,
            type: EventKitCalendarMapping.calendarTypeLabel(calendar.type)
        )
    }

    private func mapEvent(_ event: EKEvent) -> BridgeEvent {
        let fields = EventKitEventFields.extract(from: event)
        let notes = fields.hasNotes ? fields.notes : nil
        let joinURL = JoinURLDetection.detectJoinURL(
            location: fields.location,
            url: fields.url?.absoluteString,
            notes: notes
        )
        return BridgeEvent(
            eventIdentifier: fields.eventIdentifier,
            calendarItemIdentifier: fields.calendarItemIdentifier,
            title: fields.title,
            location: fields.location,
            notes: notes,
            url: fields.url?.absoluteString,
            startDate: formatInstant(fields.startDate),
            endDate: formatInstant(fields.endDate),
            isAllDay: fields.isAllDay,
            joinURL: joinURL?.absoluteString,
            calendarIdentifier: fields.calendarIdentifier,
            calendarTitle: fields.calendarTitle,
            calendarColorHex: EventKitCalendarMapping.colorHexOrGray(event.calendar.color),
            allowsContentModifications: fields.allowsContentModifications,
            hasAttendees: fields.hasAttendees,
            participationStatus: EventParticipationMapping.bridgeStatusName(
                hasAttendees: fields.hasAttendees,
                eventKitRawValue: fields.participationRawValue
            )
        )
    }

    private func parseDateBoundary(_ value: String, endOfDay: Bool) -> Date? {
        if value.count == 10, let day = dayFormatter.date(from: value) {
            return boundaryDate(for: day, endOfDay: endOfDay)
        }
        if let instant = parseInstant(value) {
            return instant
        }
        guard let day = dayFormatter.date(from: value) else { return nil }
        return boundaryDate(for: day, endOfDay: endOfDay)
    }

    private func boundaryDate(for day: Date, endOfDay: Bool) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        if endOfDay {
            components.hour = 23
            components.minute = 59
            components.second = 59
        } else {
            components.hour = 0
            components.minute = 0
            components.second = 0
        }
        return Calendar.current.date(from: components)
    }

    private func parseInstant(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let date = isoFormatter.date(from: value) {
            return date
        }
        if let date = isoFormatterNoFraction.date(from: value) {
            return date
        }
        return dayFormatter.date(from: value)
    }

    private func formatInstant(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

}
