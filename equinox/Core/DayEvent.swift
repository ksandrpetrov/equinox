import Foundation

/// Every dated, day-based recurrence rule ends on this original occurrence's day.
/// Detached occurrences and count-limited or unbounded rules cannot establish this.
func isFinalRecurrenceDay(
    occurrenceDate: Date,
    ruleEndDates: [Date?],
    isDetached: Bool,
    calendar: Calendar
) -> Bool {
    guard !isDetached, !ruleEndDates.isEmpty,
          occurrenceDate.timeIntervalSinceReferenceDate.isFinite else { return false }
    return ruleEndDates.allSatisfy { end in
        guard let end, end.timeIntervalSinceReferenceDate.isFinite,
              end >= occurrenceDate else { return false }
        return calendar.isDate(end, inSameDayAs: occurrenceDate)
    }
}

struct DayEvent: Identifiable, Sendable, Equatable {
    let id: String
    let eventIdentifier: String?
    let calendarItemIdentifier: String
    let title: String
    let location: String?
    let notes: String?
    let url: URL?
    let startDate: Date
    let endDate: Date
    let slotStartDate: Date
    let slotEndDate: Date
    let isEventAllDay: Bool
    let isSlotAllDay: Bool
    let joinURL: URL?
    let calendarIdentifier: String
    let calendarTitle: String
    let calendarColorRed: CGFloat
    let calendarColorGreen: CGFloat
    let calendarColorBlue: CGFloat
    let calendarColorAlpha: CGFloat
    let isRecurring: Bool
    let allowsContentModifications: Bool
    let participationStatus: EventParticipationStatus?

    var allowsDeletion: Bool {
        eventIdentifier != nil && allowsContentModifications && participationStatus != .declined
    }

    var displaysAsAllDay: Bool {
        isEventAllDay || isSlotAllDay
    }

    func representsSameOccurrence(as other: DayEvent) -> Bool {
        if let eventIdentifier, let otherIdentifier = other.eventIdentifier {
            return eventIdentifier == otherIdentifier && startDate == other.startDate
        }
        return calendarItemIdentifier == other.calendarItemIdentifier
            && startDate == other.startDate
    }

}
