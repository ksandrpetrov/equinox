import AppKit
import EventKit
import Foundation

enum DayEventMapping {
    static func dayEvent(
        from event: EKEvent,
        slot: EventDaySlot,
        joinURL: URL?,
        dayKey: Date
    ) -> DayEvent {
        let fields = EventKitEventFields.extract(from: event)
        let color = event.calendar.color ?? .gray
        let components = EventKitCalendarMapping.rgbComponents(from: color)
        let syntheticID: String
        if let eventID = fields.eventIdentifier {
            syntheticID = "\(dayKey.timeIntervalSince1970)-\(eventID)"
        } else {
            syntheticID = "\(dayKey.timeIntervalSince1970)-\(fields.calendarItemIdentifier)-\(fields.startDate.timeIntervalSince1970)"
        }
        return DayEvent(
            id: syntheticID,
            eventIdentifier: fields.eventIdentifier,
            calendarItemIdentifier: fields.calendarItemIdentifier,
            title: fields.title,
            location: fields.location,
            notes: fields.notes,
            url: fields.url,
            startDate: fields.startDate,
            endDate: fields.endDate,
            isEventAllDay: fields.isAllDay,
            isFirstDayOfSpan: slot.isFirstDayOfSpan,
            isLastDayOfSpan: slot.isLastDayOfSpan,
            isSlotAllDay: slot.displaysAsAllDay,
            joinURL: joinURL,
            calendarIdentifier: fields.calendarIdentifier,
            calendarTitle: fields.calendarTitle,
            calendarColorRed: components.red,
            calendarColorGreen: components.green,
            calendarColorBlue: components.blue,
            calendarColorAlpha: components.alpha,
            allowsContentModifications: fields.allowsContentModifications,
            hasAttendees: fields.hasAttendees,
            participationStatus: EventParticipationMapping.status(
                hasAttendees: fields.hasAttendees,
                eventKitRawValue: fields.participationRawValue
            )
        )
    }
}
