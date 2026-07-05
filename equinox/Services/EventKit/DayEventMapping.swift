import EventKit
import Foundation

enum DayEventMapping {
    static func dayEvent(
        from event: EKEvent,
        slot: EventDaySlot,
        joinURL: URL?,
        dayKey: Date
    ) -> DayEvent {
        dayEvent(
            from: EventKitEventFields.extract(from: event),
            calendarColor: event.calendar.cgColor,
            slot: slot,
            joinURL: joinURL,
            dayKey: dayKey
        )
    }

    static func dayEvent(
        from fields: EventKitEventFields,
        calendarColor: CGColor?,
        slot: EventDaySlot,
        joinURL: URL?,
        dayKey: Date
    ) -> DayEvent {
        let components = EventKitCalendarMapping.rgbComponents(
            from: calendarColor ?? CGColor(gray: 0.5, alpha: 1)
        )
        return dayEvent(
            from: fields,
            calendarColorComponents: (components.red, components.green, components.blue, components.alpha),
            slot: slot,
            joinURL: joinURL,
            dayKey: dayKey
        )
    }

    static func dayEvent(
        from fields: EventKitEventFields,
        calendarColorComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat),
        slot: EventDaySlot,
        joinURL: URL?,
        dayKey: Date
    ) -> DayEvent {
        let components = calendarColorComponents
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
