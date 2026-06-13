import Foundation

struct EventLayoutInput: Sendable {
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
}

struct EventDaySlot: Sendable, Equatable {
    let dayStart: Date
    let isFirstDayOfSpan: Bool
    let isLastDayOfSpan: Bool
    let displaysAsAllDay: Bool
}

/// Buckets a single event into per-day slots within a fetch range.
func layoutEventDaySlots(
    event: EventLayoutInput,
    rangeStart: Date,
    rangeEnd: Date,
    calendar: Calendar
) -> [EventDaySlot] {
    var date = max(event.startDate, rangeStart)
    let final = min(event.endDate, rangeEnd)
    date = calendar.startOfDay(for: date)
    guard date < final else { return [] }

    var slots: [EventDaySlot] = []
    while date < final {
        let nextDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date)!)
        slots.append(EventDaySlot(
            dayStart: date,
            isFirstDayOfSpan: calendar.isDate(date, inSameDayAs: event.startDate) && event.endDate >= nextDate,
            isLastDayOfSpan: calendar.isDate(date, inSameDayAs: event.endDate) && event.startDate < date,
            displaysAsAllDay: event.isAllDay || (event.startDate < date && event.endDate >= nextDate)
        ))
        date = nextDate
    }
    return slots
}

struct EventSortKey: Sendable {
    let isEventAllDay: Bool
    let isSlotAllDay: Bool
    let calendarTitle: String
    let startDate: Date
}

/// Sort order for events displayed on a single day (all-day first, then by start time, then calendar title).
func precedesInDisplayOrder(_ lhs: EventSortKey, _ rhs: EventSortKey) -> Bool {
    if lhs.isEventAllDay && rhs.isEventAllDay {
        return lhs.calendarTitle.localizedStandardCompare(rhs.calendarTitle) == .orderedAscending
    }
    if lhs.isEventAllDay && !rhs.isEventAllDay { return true }
    if !lhs.isEventAllDay && rhs.isEventAllDay { return false }
    if lhs.isSlotAllDay && rhs.isSlotAllDay {
        return lhs.calendarTitle.localizedStandardCompare(rhs.calendarTitle) == .orderedAscending
    }
    if lhs.isSlotAllDay { return true }
    if rhs.isSlotAllDay { return false }
    return lhs.startDate < rhs.startDate
}
