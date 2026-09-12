import Foundation

struct CalendarStoreSnapshot: Sendable {
    let accessStatus: CalendarAccessStatus
    let eventsByDate: [CalendarDate: [DayEvent]]
    let calendarEntries: [CalendarListEntry]
    let defaultCalendarIdentifier: String?
    let hasSelectedCalendars: Bool
    let lastFetchError: String?
    let hasCompletedInitialLoad: Bool
}

protocol CalendarEventStore: Sendable {
    func snapshot() async -> CalendarStoreSnapshot
    func setExternalChangeHandler(_ handler: @escaping @Sendable () -> Void) async
    func requestCalendarAccessIfNeeded() async -> Bool
    func fetchEvents(first: CalendarDate, last: CalendarDate, refetch: Bool) async -> Bool
    func refetchAll(first: CalendarDate, last: CalendarDate) async -> Bool
    func invalidateTimeContext() async
    func createEvent(from draft: NewEventDraft) async throws
    func deleteEvent(identifier: String, occurrenceStartDate: Date) async throws
    func updateSelectedCalendar(identifier: String, selected: Bool) async
    func resetCalendarSelection() async
}
