import Foundation

struct BridgeResponse: Encodable {
    let ok: Bool
    let data: BridgeData?
    let error: BridgeError?

    static func success(_ data: BridgeData) -> BridgeResponse {
        BridgeResponse(ok: true, data: data, error: nil)
    }

    static func failure(code: String, message: String) -> BridgeResponse {
        BridgeResponse(ok: false, data: nil, error: BridgeError(code: code, message: message))
    }
}

struct BridgeError: Encodable {
    let code: String
    let message: String
}

enum BridgeData: Encodable {
    case accessStatus(AccessStatusData)
    case accessRequest(AccessRequestData)
    case calendars(CalendarsData)
    case events(EventsData)
    case event(EventData)
    case mutation(MutationData)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .accessStatus(let value):
            try container.encode(value)
        case .accessRequest(let value):
            try container.encode(value)
        case .calendars(let value):
            try container.encode(value)
        case .events(let value):
            try container.encode(value)
        case .event(let value):
            try container.encode(value)
        case .mutation(let value):
            try container.encode(value)
        }
    }
}

struct AccessStatusData: Encodable {
    let status: String
    let granted: Bool
}

struct AccessRequestData: Encodable {
    let granted: Bool
    let status: String
}

struct CalendarsData: Encodable {
    let calendars: [BridgeCalendar]
}

struct EventsData: Encodable {
    let events: [BridgeEvent]
    let truncated: Bool
}

struct EventData: Encodable {
    let event: BridgeEvent
}

struct MutationData: Encodable {
    let eventIdentifier: String?
    let calendarItemIdentifier: String?
}

struct BridgeCalendar: Encodable {
    let id: String
    let title: String
    let sourceTitle: String
    let sourceIdentifier: String
    let colorHex: String
    let allowsContentModifications: Bool
    let isSubscribed: Bool
    let type: String
}

struct BridgeEvent: Encodable {
    let eventIdentifier: String?
    let calendarItemIdentifier: String
    let title: String
    let location: String?
    let notes: String?
    let url: String?
    let startDate: String
    let endDate: String
    let isAllDay: Bool
    let joinURL: String?
    let calendarIdentifier: String
    let calendarTitle: String
    let calendarColorHex: String
    let allowsContentModifications: Bool
    let hasAttendees: Bool
    let participationStatus: String?
}

struct BridgeCommand: Decodable {
    let command: String
    let startDate: String?
    let endDate: String?
    let calendarIds: [String]?
    let eventIdentifier: String?
    let title: String?
    let calendarId: String?
    let allDay: Bool?
    let location: String?
    let notes: String?
    let url: String?
    let span: String?
    let limit: Int?
}
