import Foundation

enum EventParticipationStatus: Int, Sendable, Equatable, CaseIterable {
    case unknown = 0
    case pending = 1
    case accepted = 2
    case declined = 3
    case tentative = 4

    var needsResponse: Bool {
        switch self {
        case .pending, .unknown:
            return true
        case .accepted, .declined, .tentative:
            return false
        }
    }

    var localizedLabel: String {
        switch self {
        case .unknown, .pending:
            return String(localized: "Awaiting response", comment: "RSVP status badge")
        case .accepted:
            return String(localized: "Going", comment: "RSVP status accepted")
        case .tentative:
            return String(localized: "Maybe", comment: "RSVP status tentative")
        case .declined:
            return String(localized: "Declined", comment: "RSVP status declined")
        }
    }

    var detailStatusLabel: String {
        switch self {
        case .unknown, .pending:
            return String(localized: "You haven't responded yet", comment: "RSVP detail status")
        case .accepted:
            return String(localized: "You're going", comment: "RSVP detail status")
        case .tentative:
            return String(localized: "You responded maybe", comment: "RSVP detail status")
        case .declined:
            return String(localized: "You declined", comment: "RSVP detail status")
        }
    }

    static func fromEventKitRawValue(_ rawValue: Int) -> EventParticipationStatus? {
        EventParticipationStatus(rawValue: rawValue)
    }
}

enum EventParticipationMapping {
    static func status(hasAttendees: Bool, eventKitRawValue: Int?) -> EventParticipationStatus? {
        guard hasAttendees else { return nil }
        guard let rawValue = eventKitRawValue else { return .unknown }
        return EventParticipationStatus.fromEventKitRawValue(rawValue) ?? .unknown
    }

    static func isDeclinedParticipation(hasAttendees: Bool, eventKitRawValue: Int?) -> Bool {
        guard hasAttendees, let rawValue = eventKitRawValue else { return false }
        return rawValue == EventParticipationStatus.declined.rawValue
    }

    static func bridgeStatusName(hasAttendees: Bool, eventKitRawValue: Int?) -> String? {
        guard let status = status(hasAttendees: hasAttendees, eventKitRawValue: eventKitRawValue) else {
            return nil
        }
        switch status {
        case .unknown: return "unknown"
        case .pending: return "pending"
        case .accepted: return "accepted"
        case .declined: return "declined"
        case .tentative: return "tentative"
        }
    }
}
