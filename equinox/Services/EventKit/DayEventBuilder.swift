import EventKit
import Foundation

struct DayEventSource: Sendable {
    let fields: EventKitEventFields
    let calendarColorRed: CGFloat
    let calendarColorGreen: CGFloat
    let calendarColorBlue: CGFloat
    let calendarColorAlpha: CGFloat

    static func extract(from event: EKEvent) -> DayEventSource {
        let components = EventKitCalendarMapping.rgbComponents(
            from: event.calendar.cgColor ?? CGColor(gray: 0.5, alpha: 1)
        )
        return DayEventSource(
            fields: EventKitEventFields.extract(from: event),
            calendarColorRed: components.red,
            calendarColorGreen: components.green,
            calendarColorBlue: components.blue,
            calendarColorAlpha: components.alpha
        )
    }
}

typealias ResolveNativeJoinURL = @Sendable (URL) async -> URL?

/// Builds display-ready `DayEvent` day slots from EventKit events.
enum DayEventBuilder {
    static func buildDayEvents(
        from sources: [DayEventSource],
        rangeStart: Date,
        rangeEnd: Date,
        calendar: Calendar,
        resolveNativeJoinURL: ResolveNativeJoinURL
    ) async -> [Date: [DayEvent]] {
        var newEventsForDate: [Date: [DayEvent]] = [:]

        for source in sources {
            let fields = source.fields
            let layoutInput = EventLayoutInput(
                startDate: fields.startDate,
                endDate: fields.endDate,
                isAllDay: fields.isAllDay,
                calendarTitle: fields.calendarTitle
            )
            let slots = layoutEventDaySlots(
                event: layoutInput,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                calendar: calendar
            )
            let notes = fields.hasNotes ? fields.notes : nil
            let webJoinURL = JoinURLDetection.detectJoinURL(
                location: fields.location,
                url: fields.url?.absoluteString,
                notes: notes
            )
            let joinURL: URL?
            if let webJoinURL {
                joinURL = await resolveNativeJoinURL(webJoinURL) ?? webJoinURL
            } else {
                joinURL = nil
            }

            for slot in slots {
                let dayEvent = DayEventMapping.dayEvent(
                    from: fields,
                    calendarColorComponents: (
                        red: source.calendarColorRed,
                        green: source.calendarColorGreen,
                        blue: source.calendarColorBlue,
                        alpha: source.calendarColorAlpha
                    ),
                    slot: slot,
                    joinURL: joinURL,
                    dayKey: slot.dayStart
                )
                if newEventsForDate[slot.dayStart] == nil {
                    newEventsForDate[slot.dayStart] = []
                }
                newEventsForDate[slot.dayStart]?.append(dayEvent)
            }
        }

        for date in newEventsForDate.keys {
            newEventsForDate[date]?.sort { lhs, rhs in
                precedesInDisplayOrder(
                    EventSortKey(
                        isEventAllDay: lhs.isEventAllDay,
                        isSlotAllDay: lhs.isSlotAllDay,
                        calendarTitle: lhs.calendarTitle,
                        startDate: lhs.startDate
                    ),
                    EventSortKey(
                        isEventAllDay: rhs.isEventAllDay,
                        isSlotAllDay: rhs.isSlotAllDay,
                        calendarTitle: rhs.calendarTitle,
                        startDate: rhs.startDate
                    )
                )
            }
        }

        return newEventsForDate
    }
}
