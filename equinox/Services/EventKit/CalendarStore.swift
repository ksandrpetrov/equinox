import EventKit
import Foundation

actor CalendarStore {
    private let store = EKEventStore()
    private let calendar: Calendar
    private let isNativeAppInstalled: NativeAppInstalledChecker
    private let externalChangeDispatcher = ExternalChangeDispatcher()
    private nonisolated(unsafe) var storeObserver: NSObjectProtocol?

    private var fetchCache = EventFetchCache()
    private var calendarSelection = CalendarSelectionService()

    var lastFetchError: String? { fetchCache.lastFetchError }

    var hasCalendarAccess: Bool {
        accessStatus() == .authorized
    }

    func accessStatus() -> CalendarAccessStatus {
        CalendarAccessMapping.guiAccessStatus()
    }

    func hasSelectedCalendars() -> Bool {
        calendarSelection.hasSelectedCalendars()
    }

    init(
        calendar: Calendar,
        isNativeAppInstalled: @escaping NativeAppInstalledChecker = NativeJoinURLResolver.defaultInstalledChecker
    ) {
        self.calendar = calendar
        self.isNativeAppInstalled = isNativeAppInstalled

        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [externalChangeDispatcher] _ in
            externalChangeDispatcher.notify()
        }
    }

    func setExternalChangeHandler(_ handler: @escaping @Sendable () -> Void) {
        externalChangeDispatcher.setHandler(handler)
    }

    deinit {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
    }

    func selectedCalendarEvents() -> [CalendarDate: [DayEvent]] {
        fetchCache.selectedCalendarEvents(calendar: calendar)
    }

    func calendarEntries() -> [CalendarListEntry] {
        calendarSelection.calendarEntries
    }

    func defaultCalendarIdentifierForNewEvents() -> String? {
        guard let calendar = store.defaultCalendarForNewEvents,
              calendar.allowsContentModifications else { return nil }
        return calendar.calendarIdentifier
    }

    func requestCalendarAccessIfNeeded() async -> Bool {
        switch accessStatus() {
        case .authorized:
            prepareStore()
            return true
        case .denied, .restricted:
            fetchCache.clearEvents()
            return false
        case .notDetermined:
            break
        }

        let granted = await withCheckedContinuation { continuation in
            store.requestFullAccessToEvents { @Sendable granted, _ in
                continuation.resume(returning: granted)
            }
        }

        if granted {
            prepareStore()
            return true
        }
        fetchCache.clearEvents()
        return false
    }

    func fetchEvents(first: CalendarDate, last: CalendarDate, refetch: Bool = false) async -> Bool {
        let primarySucceeded = await fetchEventsWithStartDate(
            first,
            endDate: last,
            refetch: refetch
        )
        guard primarySucceeded else { return false }

        let today = CalendarDate.today(calendar: calendar)
        let meetingMonitorLast = min(today.addingDays(1), CalendarDate.maximumSupported)
        var retainedRanges = [(first: first, last: last)]
        if today < first || meetingMonitorLast > last {
            let todaySucceeded = await fetchEventsWithStartDate(
                today,
                endDate: meetingMonitorLast,
                refetch: refetch,
                preparesStoreOnRefetch: false
            )
            guard todaySucceeded else { return false }
            retainedRanges.append((first: today, last: meetingMonitorLast))
        }
        if refetch {
            fetchCache.retainEvents(inside: retainedRanges, calendar: calendar)
            applyCalendarFilter()
        }
        return true
    }

    func refetchAll(first: CalendarDate, last: CalendarDate) async -> Bool {
        await fetchEvents(first: first, last: last, refetch: true)
    }

    func createEvent(from draft: NewEventDraft) throws {
        guard let ekCalendar = store.calendar(withIdentifier: draft.calendarIdentifier) else {
            throw CalendarStoreError.calendarNotFound
        }
        guard ekCalendar.allowsContentModifications else {
            throw CalendarStoreError.readOnlyCalendar
        }
        guard draft.endDate > draft.startDate else {
            throw CalendarStoreError.endDateBeforeStart
        }

        let event = EKEvent(eventStore: store)
        EventKitMutation.applyCreate(from: draft, to: event, calendar: ekCalendar)

        try store.save(event, span: .thisEvent, commit: true)
    }

    func deleteEvent(identifier: String, occurrenceStartDate: Date) throws {
        guard let event = eventOccurrence(
            identifier: identifier,
            occurrenceStartDate: occurrenceStartDate
        ) else {
            throw CalendarStoreError.eventNotFound
        }
        if EventParticipationMapping.isDeclinedParticipation(
            eventKitRawValue: event.equinoxParticipationRawValue
        ) {
            throw CalendarStoreError.eventNotFound
        }
        guard event.calendar.allowsContentModifications else {
            throw CalendarStoreError.readOnlyCalendar
        }
        try store.remove(event, span: .thisEvent, commit: true)
    }

    func updateSelectedCalendar(identifier: String, selected: Bool) async {
        calendarSelection.updateSelectedCalendar(identifier: identifier, selected: selected)
        applyCalendarFilter()
    }

    func resetCalendarSelection() {
        calendarSelection = CalendarSelectionService()
        guard hasCalendarAccess else {
            applyCalendarFilter()
            return
        }
        prepareStore()
        applyCalendarFilter()
    }

    // MARK: - Private

    private func prepareStore() {
        refreshEventKitStore()
        calendarSelection.refresh(from: store)
    }

    private func refreshEventKitStore() {
        store.reset()
        store.refreshSourcesIfNecessary()
    }

    private func eventOccurrence(identifier: String, occurrenceStartDate: Date) -> EKEvent? {
        if let directMatch = store.event(withIdentifier: identifier),
           directMatch.startDate == occurrenceStartDate {
            return directMatch
        }

        // EventKit documents `event(withIdentifier:)` as returning the first matching
        // occurrence. Query around the captured start date so deleting a recurring event
        // removes the occurrence the user actually selected.
        let predicate = store.predicateForEvents(
            withStart: occurrenceStartDate.addingTimeInterval(-1),
            end: occurrenceStartDate.addingTimeInterval(1),
            calendars: nil
        )
        return store.events(matching: predicate).first {
            $0.eventIdentifier == identifier && $0.startDate == occurrenceStartDate
        }
    }

    private func fetchEventsWithStartDate(
        _ startDate: CalendarDate,
        endDate: CalendarDate,
        refetch: Bool,
        preparesStoreOnRefetch: Bool = true
    ) async -> Bool {
        guard hasCalendarAccess else {
            fetchCache.clearEvents()
            fetchCache.lastFetchError = String(localized: "Calendar access is required to load events.", comment: "Fetch error")
            return false
        }

        if refetch, preparesStoreOnRefetch {
            prepareStore()
        }

        guard let fetchRange = fetchCache.prepareFetchRange(first: startDate, last: endDate, refetch: refetch) else {
            fetchCache.lastFetchError = nil
            return true
        }

        let rangeStart = fetchRange.fetchStart.date(in: calendar)
        let rangeEnd = fetchRange.fetchEnd.addingDays(1).date(in: calendar)
        let cals = calendarSelection.validCalendars(from: store)
        guard !cals.isEmpty else {
            fetchCache.commitFetch([:], plan: fetchRange, calendar: calendar)
            applyCalendarFilter()
            return true
        }
        let predicate = store.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: cals)
        let events = store.events(matching: predicate)
        let sources = events.map(DayEventSource.extract(from:))
        let newEventsForDate = await DayEventBuilder.buildDayEvents(
            from: sources,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            calendar: calendar,
            resolveNativeJoinURL: { [isNativeAppInstalled] url in
                await NativeJoinURLResolver.resolveNativeJoinURL(from: url, isAppInstalled: isNativeAppInstalled)
            }
        )
        fetchCache.commitFetch(newEventsForDate, plan: fetchRange, calendar: calendar)
        applyCalendarFilter()
        return true
    }

    private func applyCalendarFilter() {
        fetchCache.applyCalendarFilter(selectedCalendarIDs: calendarSelection.selectedCalendarIDs())
    }

}

private final class ExternalChangeDispatcher: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable () -> Void)?
    private var pendingChange = false

    func setHandler(_ handler: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
        if pendingChange {
            pendingChange = false
            handler()
        }
    }

    func notify() {
        lock.lock()
        defer { lock.unlock() }
        if let handler {
            handler()
        } else {
            pendingChange = true
        }
    }
}

enum CalendarStoreError: Error, LocalizedError {
    case eventNotFound
    case calendarNotFound
    case readOnlyCalendar
    case endDateBeforeStart

    var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return String(localized: "The event could not be found.", comment: "Delete event error")
        case .calendarNotFound:
            return String(localized: "The calendar could not be found.", comment: "Create event error")
        case .readOnlyCalendar:
            return String(localized: "This calendar is read-only.", comment: "Create event error")
        case .endDateBeforeStart:
            return String(localized: "End date must be after start date.", comment: "Create event validation error")
        }
    }
}
