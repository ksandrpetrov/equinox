import Foundation

enum RecurrenceFrequency: Sendable, Equatable {
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly
}

struct RecurrenceDraft: Sendable, Equatable {
    let frequency: RecurrenceFrequency
    let endDate: Date?
}

struct NewEventDraft: Sendable, Equatable {
    var title: String
    var location: String
    var url: URL?
    var notes: String?
    var isAllDay: Bool
    var startDate: Date
    var endDate: Date
    var calendarIdentifier: String
    var recurrence: RecurrenceDraft?
    /// Relative alarm offset in seconds (negative = before start). `nil` = no alert.
    var alertOffset: TimeInterval?
}
