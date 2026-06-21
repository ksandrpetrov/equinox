import EventKit
import Foundation

/// Maps `EKEvent` to bridge JSON models. Shared by `EventKitBridge` and contract tests.
enum BridgeEventMapping {
    static func bridgeEvent(from event: EKEvent) -> BridgeEvent {
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
            startDate: BridgeDateParsing.formatInstant(fields.startDate),
            endDate: BridgeDateParsing.formatInstant(fields.endDate),
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
}
