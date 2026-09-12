import XCTest
@testable import EquinoxKit

@MainActor
final class StubCalendarEventStore: CalendarEventStore {
    var operations: [String] = []
    var refetchedRanges: [(first: CalendarDate, last: CalendarDate)] = []
    var readSnapshot: @MainActor () async -> CalendarStoreSnapshot = { snapshot(status: .authorized) }
    var createError: CalendarStoreError?
    var deleteError: CalendarStoreError?
    var deletedOccurrences: [(identifier: String, start: Date)] = []
    var accessRequestCount = 0
    var snapshotCount = 0
    var timeInvalidationCount = 0
    var onTimeInvalidation: () -> Void = {}
    var onSelectionChange: (String, Bool) -> Void = { _, _ in }
    var externalChangeHandler: (@Sendable () -> Void)?

    static func snapshot(
        status: CalendarAccessStatus,
        events: [CalendarDate: [DayEvent]] = [:],
        hasSelectedCalendars: Bool = true,
        hasCompletedInitialLoad: Bool = true
    ) -> CalendarStoreSnapshot {
        CalendarStoreSnapshot(
            accessStatus: status, eventsByDate: status.isAuthorized ? events : [:], calendarEntries: [],
            defaultCalendarIdentifier: status.isAuthorized ? "work" : nil,
            hasSelectedCalendars: status.isAuthorized && hasSelectedCalendars, lastFetchError: nil,
            hasCompletedInitialLoad: status.isAuthorized && hasCompletedInitialLoad
        )
    }
    func snapshot() async -> CalendarStoreSnapshot {
        snapshotCount += 1
        return await readSnapshot()
    }
    func setExternalChangeHandler(_ handler: @escaping @Sendable () -> Void) async { externalChangeHandler = handler }
    func requestCalendarAccessIfNeeded() async -> Bool {
        accessRequestCount += 1
        return true
    }
    func fetchEvents(first: CalendarDate, last: CalendarDate, refetch: Bool) async -> Bool { true }
    func refetchAll(first: CalendarDate, last: CalendarDate) async -> Bool {
        operations.append("refetch")
        refetchedRanges.append((first, last))
        return true
    }
    func invalidateTimeContext() async {
        timeInvalidationCount += 1
        onTimeInvalidation()
    }
    func createEvent(from draft: NewEventDraft) async throws {
        operations.append("create")
        if let createError { throw createError }
    }
    func deleteEvent(identifier: String, occurrenceStartDate: Date) async throws {
        operations.append("delete")
        deletedOccurrences.append((identifier, occurrenceStartDate))
        if let deleteError { throw deleteError }
    }
    func updateSelectedCalendar(identifier: String, selected: Bool) async {
        operations.append("select")
        onSelectionChange(identifier, selected)
    }
    func resetCalendarSelection() async { operations.append("reset") }
}
