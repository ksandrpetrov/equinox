import EventKit
import Foundation

/// Raw EKEvent field extraction shared by `DayEventMapping` (GUI) and
/// `EventKitBridge.mapEvent` (CLI) so both pull the same fields and stay in sync.
/// Calendar color and join-URL handling stay in each consumer because their
/// representations differ (RGBA components vs hex string, native rewrite vs web-only).
struct EventKitEventFields: Sendable {
    let eventIdentifier: String?
    let calendarItemIdentifier: String
    let title: String
    let location: String?
    let notes: String?
    let hasNotes: Bool
    let url: URL?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarIdentifier: String
    let calendarTitle: String
    let allowsContentModifications: Bool
    let hasAttendees: Bool
    let participationRawValue: Int?

    static func extract(from event: EKEvent) -> EventKitEventFields {
        EventKitEventFields(
            eventIdentifier: event.eventIdentifier,
            calendarItemIdentifier: event.calendarItemIdentifier,
            title: event.title ?? "",
            location: event.location,
            notes: event.notes,
            hasNotes: event.hasNotes,
            url: event.url,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            calendarIdentifier: event.calendar.calendarIdentifier,
            calendarTitle: event.calendar.title,
            allowsContentModifications: event.calendar.allowsContentModifications,
            hasAttendees: event.hasAttendees,
            participationRawValue: event.equinoxParticipationRawValue
        )
    }
}
