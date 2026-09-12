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

    func validate(calendar: Calendar = .equinoxGregorian()) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CalendarStoreError.emptyTitle
        }
        guard startDate.timeIntervalSinceReferenceDate.isFinite,
              endDate.timeIntervalSinceReferenceDate.isFinite,
              endDate > startDate else {
            throw CalendarStoreError.endDateBeforeStart
        }
        let supported = EventDraftDefaults.supportedDateRange(calendar: calendar)
        let exclusiveEnd = supported.upperBound.addingTimeInterval(1)
        guard startDate >= supported.lowerBound, startDate < exclusiveEnd,
              endDate <= exclusiveEnd else {
            throw CalendarStoreError.dateOutsideSupportedRange
        }
        if let url, EventDraftDefaults.absoluteURL(from: url.absoluteString) == nil {
            throw CalendarStoreError.invalidURL
        }
        if let end = recurrence?.endDate,
           !end.timeIntervalSinceReferenceDate.isFinite || end < startDate {
            throw CalendarStoreError.invalidRecurrenceEnd
        }
        if let end = recurrence?.endDate, end >= exclusiveEnd {
            throw CalendarStoreError.dateOutsideSupportedRange
        }
        if let alertOffset, !alertOffset.isFinite {
            throw CalendarStoreError.invalidAlert
        }
    }
}
