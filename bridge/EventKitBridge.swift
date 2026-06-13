import AppKit
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

        let calendars = store.calendars(for: .event)
            .filter { $0.color != nil }
            .sorted { lhs, rhs in
                if lhs.source.sourceIdentifier == rhs.source.sourceIdentifier {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                return lhs.source.title.localizedStandardCompare(rhs.source.title) == .orderedAscending
            }
            .map(mapCalendar)

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
            calendars = store.calendars(for: .event).filter { $0.color != nil }
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
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = command.allDay ?? false
        event.location = command.location
        event.notes = command.notes
        if let urlString = command.url {
            event.url = URL(string: urlString)
        }

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
        guard event.calendar.allowsContentModifications else {
            return .failure(code: "read_only_calendar", message: "Event calendar does not allow modifications")
        }

        if let title = command.title {
            event.title = title
        }
        if let start = parseInstant(command.startDate) {
            event.startDate = start
        }
        if let end = parseInstant(command.endDate) {
            event.endDate = end
        }
        if let allDay = command.allDay {
            event.isAllDay = allDay
        }
        if let location = command.location {
            event.location = location
        }
        if let notes = command.notes {
            event.notes = notes
        }
        if let urlString = command.url {
            event.url = URL(string: urlString)
        }
        if let calendarId = command.calendarId, let calendar = store.calendar(withIdentifier: calendarId) {
            guard calendar.allowsContentModifications else {
                return .failure(code: "read_only_calendar", message: "Target calendar does not allow modifications")
            }
            event.calendar = calendar
        }

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
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return ("full_access", true)
        case .writeOnly:
            return ("write_only", false)
        case .notDetermined:
            return ("not_determined", false)
        case .restricted:
            return ("restricted", false)
        case .denied:
            return ("denied", false)
        @unknown default:
            return ("unknown", false)
        }
    }

    private func isDeclined(_ event: EKEvent) -> Bool {
        EventParticipationMapping.isDeclinedParticipation(
            hasAttendees: event.hasAttendees,
            eventKitRawValue: event.value(forKey: "participationStatus") as? Int
        )
    }

    private func mapCalendar(_ calendar: EKCalendar) -> BridgeCalendar {
        BridgeCalendar(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: calendar.source.title,
            sourceIdentifier: calendar.source.sourceIdentifier,
            colorHex: colorHex(calendar.color),
            allowsContentModifications: calendar.allowsContentModifications,
            isSubscribed: calendar.isSubscribed,
            type: calendarTypeLabel(calendar.type)
        )
    }

    private func mapEvent(_ event: EKEvent) -> BridgeEvent {
        let joinURL = JoinURLDetection.detectJoinURL(
            location: event.location,
            url: event.url?.absoluteString,
            notes: event.hasNotes ? event.notes : nil
        )
        return BridgeEvent(
            eventIdentifier: event.eventIdentifier,
            calendarItemIdentifier: event.calendarItemIdentifier,
            title: event.title ?? "",
            location: event.location,
            notes: event.hasNotes ? event.notes : nil,
            url: event.url?.absoluteString,
            startDate: formatInstant(event.startDate),
            endDate: formatInstant(event.endDate),
            isAllDay: event.isAllDay,
            joinURL: joinURL?.absoluteString,
            calendarIdentifier: event.calendar.calendarIdentifier,
            calendarTitle: event.calendar.title,
            calendarColorHex: colorHex(event.calendar.color),
            allowsContentModifications: event.calendar.allowsContentModifications,
            hasAttendees: event.hasAttendees
        )
    }

    private func parseDateBoundary(_ value: String, endOfDay: Bool) -> Date? {
        if let instant = parseInstant(value) {
            return instant
        }
        guard let day = dayFormatter.date(from: value) else { return nil }
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

    private func colorHex(_ color: NSColor?) -> String {
        guard let color else { return "#808080" }
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let red = Int(round(rgb.redComponent * 255))
        let green = Int(round(rgb.greenComponent * 255))
        let blue = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private func calendarTypeLabel(_ type: EKCalendarType) -> String {
        switch type {
        case .local: return "local"
        case .calDAV: return "caldav"
        case .exchange: return "exchange"
        case .subscription: return "subscription"
        case .birthday: return "birthday"
        @unknown default: return "unknown"
        }
    }
}