import Foundation

enum CalendarStoreError: Error, LocalizedError, Equatable {
    case eventNotFound
    case calendarNotFound
    case readOnlyCalendar
    case endDateBeforeStart
    case dateOutsideSupportedRange
    case emptyTitle
    case invalidURL
    case invalidRecurrenceEnd
    case invalidAlert
    case calendarAccessRequired

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return String(localized: "Enter an event title.", bundle: .equinox, comment: "Create event title validation error")
        case .invalidURL:
            return String(localized: "Enter a valid URL including its scheme.", bundle: .equinox, comment: "Create event URL validation error")
        case .invalidRecurrenceEnd:
            return String(localized: "Repeat end date cannot be before event start.", bundle: .equinox, comment: "Create event recurrence validation error")
        case .invalidAlert:
            return String(localized: "Enter a valid event alert.", bundle: .equinox, comment: "Create event alert validation error")
        case .calendarAccessRequired:
            return String(localized: "Calendar access required", bundle: .equinox, comment: "Permission banner title")
        case .eventNotFound:
            return String(localized: "The event could not be found.", bundle: .equinox, comment: "Delete event error")
        case .calendarNotFound:
            return String(localized: "The calendar could not be found.", bundle: .equinox, comment: "Create event error")
        case .readOnlyCalendar:
            return String(localized: "This calendar is read-only.", bundle: .equinox, comment: "Create event error")
        case .endDateBeforeStart:
            return String(localized: "End date must be after start date.", bundle: .equinox, comment: "Create event validation error")
        case .dateOutsideSupportedRange:
            return String(localized: "Event dates must be between 1583 and 3333.", bundle: .equinox, comment: "Supported event date range validation error")
        }
    }
}
