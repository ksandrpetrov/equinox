import EventKit
import Foundation

typealias ResolveNativeJoinURL = @Sendable (URL) async -> URL?

/// Builds display-ready `DayEvent` day slots from EventKit events.
enum DayEventBuilder {
    static func buildDayEvents(
        from events: [EKEvent],
        rangeStart: Date,
        rangeEnd: Date,
        calendar: Calendar,
        resolveNativeJoinURL: ResolveNativeJoinURL
    ) async -> [Date: [DayEvent]] {
        var newEventsForDate: [Date: [DayEvent]] = [:]

        for event in events {
            let fields = EventKitEventFields.extract(from: event)
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
                    from: event,
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
