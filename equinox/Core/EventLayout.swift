import Foundation

struct EventLayoutInput: Sendable {
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}

struct EventDaySlot: Sendable, Equatable {
    let dayStart: Date
    let startDate: Date
    let endDate: Date
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
        guard let followingDay = calendar.date(byAdding: .day, value: 1, to: date) else {
            break
        }
        let nextDate = calendar.startOfDay(for: followingDay)
        guard nextDate > date else { break }
        let slotStart = max(max(event.startDate, rangeStart), date)
        let slotEnd = min(min(event.endDate, rangeEnd), nextDate)
        guard slotStart < slotEnd else {
            date = nextDate
            continue
        }
        slots.append(EventDaySlot(
            dayStart: date,
            startDate: slotStart,
            endDate: slotEnd,
            displaysAsAllDay: event.isAllDay || (slotStart <= date && slotEnd >= nextDate)
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
    let title: String
    let stableIdentifier: String
}

/// Sort order for events displayed on a single day (all-day first, then by start time, then calendar title).
func precedesInDisplayOrder(_ lhs: EventSortKey, _ rhs: EventSortKey) -> Bool {
    if lhs.isEventAllDay && rhs.isEventAllDay {
        return precedesByStableTextOrder(lhs, rhs)
    }
    if lhs.isEventAllDay && !rhs.isEventAllDay { return true }
    if !lhs.isEventAllDay && rhs.isEventAllDay { return false }
    if lhs.isSlotAllDay && rhs.isSlotAllDay {
        return precedesByStableTextOrder(lhs, rhs)
    }
    if lhs.isSlotAllDay { return true }
    if rhs.isSlotAllDay { return false }
    if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
    return precedesByStableTextOrder(lhs, rhs)
}

private func precedesByStableTextOrder(_ lhs: EventSortKey, _ rhs: EventSortKey) -> Bool {
    for pair in [(lhs.calendarTitle, rhs.calendarTitle), (lhs.title, rhs.title)] {
        switch pair.0.localizedStandardCompare(pair.1) {
        case .orderedAscending:
            return true
        case .orderedDescending:
            return false
        case .orderedSame:
            if pair.0 != pair.1 { return pair.0 < pair.1 }
        }
    }
    return lhs.stableIdentifier < rhs.stableIdentifier
}
