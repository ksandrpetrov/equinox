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
        var resolvedJoinURLs: [URL: URL] = [:]

        for source in sources {
            let fields = source.fields
            let layoutInput = EventLayoutInput(
                startDate: fields.startDate,
                endDate: fields.endDate,
                isAllDay: fields.isAllDay
            )
            let slots = layoutEventDaySlots(
                event: layoutInput,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                calendar: calendar
            )
            guard !slots.isEmpty else { continue }
            let notes = fields.hasNotes ? fields.notes : nil
            let webJoinURL = JoinURLDetection.detectJoinURL(
                location: fields.location,
                url: fields.url?.absoluteString,
                notes: notes
            )
            let joinURL: URL?
            if let webJoinURL {
                if let cached = resolvedJoinURLs[webJoinURL] {
                    joinURL = cached
                } else {
                    let resolved = await resolveNativeJoinURL(webJoinURL) ?? webJoinURL
                    resolvedJoinURLs[webJoinURL] = resolved
                    joinURL = resolved
                }
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
                newEventsForDate[slot.dayStart, default: []].append(dayEvent)
            }
        }

        for date in newEventsForDate.keys {
            newEventsForDate[date]?.sort { lhs, rhs in
                precedesInDisplayOrder(
                    EventSortKey(
                        isEventAllDay: lhs.isEventAllDay,
                        isSlotAllDay: lhs.isSlotAllDay,
                        calendarTitle: lhs.calendarTitle,
                        startDate: lhs.slotStartDate,
                        title: lhs.title,
                        stableIdentifier: lhs.id
                    ),
                    EventSortKey(
                        isEventAllDay: rhs.isEventAllDay,
                        isSlotAllDay: rhs.isSlotAllDay,
                        calendarTitle: rhs.calendarTitle,
                        startDate: rhs.slotStartDate,
                        title: rhs.title,
                        stableIdentifier: rhs.id
                    )
                )
            }
        }

        return newEventsForDate
    }
}
