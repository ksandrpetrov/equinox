import Foundation

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
    let isEventAllDay: Bool
    let isSlotAllDay: Bool
    let joinURL: URL?
    let calendarIdentifier: String
    let calendarTitle: String
    let calendarColorRed: CGFloat
    let calendarColorGreen: CGFloat
    let calendarColorBlue: CGFloat
    let calendarColorAlpha: CGFloat
    let allowsContentModifications: Bool
    let participationStatus: EventParticipationStatus?

    var allowsDeletion: Bool {
        eventIdentifier != nil && allowsContentModifications && participationStatus != .declined
    }

    func representsSameOccurrence(as other: DayEvent) -> Bool {
        if let eventIdentifier, let otherIdentifier = other.eventIdentifier {
            return eventIdentifier == otherIdentifier && startDate == other.startDate
        }
        return calendarItemIdentifier == other.calendarItemIdentifier
            && startDate == other.startDate
    }

}
