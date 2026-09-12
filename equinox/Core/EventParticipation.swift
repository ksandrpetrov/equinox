import Foundation

enum EventParticipationStatus: Int, Sendable, Equatable, CaseIterable {
    case unknown = 0
    case pending = 1
    case accepted = 2
    case declined = 3
    case tentative = 4
    case delegated = 5
    case completed = 6
    case inProcess = 7

    var localizedLabel: String {
        switch self {
        case .unknown, .pending:
            return String(localized: "Awaiting response", bundle: .equinox, comment: "RSVP status badge")
        case .accepted:
            return String(localized: "Going", bundle: .equinox, comment: "RSVP status accepted")
        case .tentative:
            return String(localized: "Maybe", bundle: .equinox, comment: "RSVP status tentative")
        case .declined:
            return String(localized: "Declined", bundle: .equinox, comment: "RSVP status declined")
        case .delegated:
            return String(localized: "Delegated", bundle: .equinox, comment: "RSVP status delegated")
        case .completed:
            return String(localized: "Completed", bundle: .equinox, comment: "RSVP status completed")
        case .inProcess:
            return String(localized: "In progress", bundle: .equinox, comment: "RSVP status in process")
        }
    }

    var detailStatusLabel: String {
        switch self {
        case .unknown, .pending:
            return String(localized: "You haven't responded yet", bundle: .equinox, comment: "RSVP detail status")
        case .accepted:
            return String(localized: "You're going", bundle: .equinox, comment: "RSVP detail status")
        case .tentative:
            return String(localized: "You responded maybe", bundle: .equinox, comment: "RSVP detail status")
        case .declined:
            return String(localized: "You declined", bundle: .equinox, comment: "RSVP detail status")
        case .delegated:
            return String(localized: "You delegated this invitation", bundle: .equinox, comment: "RSVP detail status")
        case .completed:
            return String(localized: "Participation completed", bundle: .equinox, comment: "RSVP detail status")
        case .inProcess:
            return String(localized: "Participation in progress", bundle: .equinox, comment: "RSVP detail status")
        }
    }

    static func fromEventKitRawValue(_ rawValue: Int) -> EventParticipationStatus? {
        EventParticipationStatus(rawValue: rawValue)
    }
}

enum EventParticipationMapping {
    static func status(eventKitRawValue: Int?) -> EventParticipationStatus? {
        guard let rawValue = eventKitRawValue else { return nil }
        return EventParticipationStatus.fromEventKitRawValue(rawValue) ?? .unknown
    }

    static func isDeclinedParticipation(eventKitRawValue: Int?) -> Bool {
        guard let rawValue = eventKitRawValue else { return false }
        return rawValue == EventParticipationStatus.declined.rawValue
    }
}
