import EventKit
import Foundation

actor CalendarStore {
    private let store = EKEventStore()
    private let calendar: Calendar
    private let isNativeAppInstalled: NativeAppInstalledChecker
    private let externalChangeDispatcher = ExternalChangeDispatcher()
    private var storeObserver: NSObjectProtocol?

    private var fetchCache = EventFetchCache()
    private var calendarSelection = CalendarSelectionService()

    var isFetchingEvents: Bool { fetchCache.isFetchingEvents }
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

    func events(for date: CalendarDate) -> [DayEvent] {
        fetchCache.events(on: date, calendar: calendar)
    }

    func calendarEntries() -> [CalendarListEntry] {
        calendarSelection.calendarEntries
    }

    func requestCalendarAccessIfNeeded() async {
        if hasCalendarAccess {
            await prepareStoreAndRefetch()
            return
        }

        let granted = await withCheckedContinuation { continuation in
            store.requestFullAccessToEvents { @Sendable granted, _ in
                continuation.resume(returning: granted)
            }
        }

        if granted {
            await prepareStoreAndRefetch()
        }
    }

    func fetchEvents(first: CalendarDate, last: CalendarDate, refetch: Bool = false) async {
        fetchCache.isFetchingEvents = true
        fetchCache.lastFetchError = nil
        fetchCache.lastFetchedFirst = first
        fetchCache.lastFetchedLast = last
        fetchCache.hasFetchedRange = true
        if refetch {
            calendarSelection.refresh(from: store)
        }
        await fetchEventsWithStartDate(first, endDate: last, refetch: refetch)
        fetchCache.isFetchingEvents = false
    }

    func refetchAll(first: CalendarDate? = nil, last: CalendarDate? = nil) async {
        if let first, let last {
            await fetchEvents(first: first, last: last, refetch: true)
            return
        }
        guard fetchCache.hasFetchedRange else {
            calendarSelection.refresh(from: store)
            return
        }
        await fetchEvents(first: fetchCache.lastFetchedFirst, last: fetchCache.lastFetchedLast, refetch: true)
    }

    func createEvent(from draft: NewEventDraft) throws {
        guard let ekCalendar = store.calendar(withIdentifier: draft.calendarIdentifier) else {
            throw CalendarStoreError.calendarNotFound
        }
        guard ekCalendar.allowsContentModifications else {
            throw CalendarStoreError.readOnlyCalendar
        }

        let event = EKEvent(eventStore: store)
        EventKitMutation.applyCreate(from: draft, to: event, calendar: ekCalendar)

        try store.save(event, span: .thisEvent, commit: true)
    }

    func deleteEvent(identifier: String) throws {
        guard let event = store.event(withIdentifier: identifier) else {
            throw CalendarStoreError.eventNotFound
        }
        if EventParticipationMapping.isDeclinedParticipation(
            hasAttendees: event.hasAttendees,
            eventKitRawValue: event.equinoxParticipationRawValue
        ) {
            throw CalendarStoreError.eventNotFound
        }
        guard event.calendar.allowsContentModifications else {
            throw CalendarStoreError.readOnlyCalendar
        }
        try store.remove(event, span: .thisEvent, commit: true)
    }

    func setParticipationStatus(_ status: EventParticipationStatus, for eventID: String) async throws {
        guard let event = store.event(withIdentifier: eventID) else {
            throw CalendarParticipationError.eventNotFound
        }
        guard event.hasAttendees else {
            throw CalendarParticipationError.notAnInvitation
        }
        do {
            try EventParticipationAccessor.apply(status, to: event)
        } catch {
            throw CalendarParticipationError.kvoFailed
        }
        try store.save(event, span: .thisEvent, commit: true)
        await refetchAll()
    }

    func updateSelectedCalendar(identifier: String, selected: Bool) async {
        calendarSelection.updateSelectedCalendar(identifier: identifier, selected: selected)
        applyCalendarFilter()
    }

    // MARK: - Private

    private func prepareStoreAndRefetch() async {
        refreshEventKitStore()
        await refetchAll()
    }

    private func refreshEventKitStore() {
        store.reset()
        store.refreshSourcesIfNecessary()
    }

    private func fetchEventsWithStartDate(
        _ startDate: CalendarDate,
        endDate: CalendarDate,
        refetch: Bool
    ) async {
        guard hasCalendarAccess else {
            fetchCache.lastFetchError = String(localized: "Calendar access is required to load events.", comment: "Fetch error")
            return
        }

        guard let fetchRange = fetchCache.prepareFetchRange(first: startDate, last: endDate, refetch: refetch) else {
            return
        }

        let rangeStart = fetchRange.fetchStart.date(in: calendar)
        let rangeEnd = fetchRange.fetchEnd.date(in: calendar)
        let cals = calendarSelection.validCalendars(from: store)
        let predicate = store.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: cals)
        let events = store.events(matching: predicate)
        let newEventsForDate = await DayEventBuilder.buildDayEvents(
            from: events,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            calendar: calendar,
            resolveNativeJoinURL: { [isNativeAppInstalled] url in
                await NativeJoinURLResolver.resolveNativeJoinURL(from: url, isAppInstalled: isNativeAppInstalled)
            }
        )
        fetchCache.mergeEvents(newEventsForDate)
        applyCalendarFilter()
    }

    private func applyCalendarFilter() {
        fetchCache.applyCalendarFilter(selectedCalendarIDs: calendarSelection.selectedCalendarIDs())
    }

    /// Returns selected-calendar events across an arbitrary span without mutating the display
    /// cache. Plaud matching uses this so links resolve for meetings outside the visible range.
    /// One `DayEvent` per underlying event (deduplicated across multi-day slots).
    func matchableEvents(from start: Date, to end: Date) async -> [DayEvent] {
        guard hasCalendarAccess, start < end else { return [] }
        let cals = calendarSelection.validCalendars(from: store)
        guard !cals.isEmpty else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: cals)
        let events = store.events(matching: predicate)
        let byDate = await DayEventBuilder.buildDayEvents(
            from: events,
            rangeStart: start,
            rangeEnd: end,
            calendar: calendar,
            resolveNativeJoinURL: { [isNativeAppInstalled] url in
                await NativeJoinURLResolver.resolveNativeJoinURL(from: url, isAppInstalled: isNativeAppInstalled)
            }
        )

        var seen = Set<String>()
        var result: [DayEvent] = []
        for dayEvents in byDate.values {
            for event in dayEvents {
                guard let eventID = event.eventIdentifier else { continue }
                let key = "\(eventID)|\(event.startDate.timeIntervalSince1970)"
                if seen.insert(key).inserted {
                    result.append(event)
                }
            }
        }
        return result
    }
}

private final class ExternalChangeDispatcher: @unchecked Sendable {
    private var handler: (@Sendable () -> Void)?
    private var pendingChange = false

    func setHandler(_ handler: @escaping @Sendable () -> Void) {
        self.handler = handler
        if pendingChange {
            pendingChange = false
            handler()
        }
    }

    func notify() {
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

    var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return String(localized: "The event could not be found.", comment: "Delete event error")
        case .calendarNotFound:
            return String(localized: "The calendar could not be found.", comment: "Create event error")
        case .readOnlyCalendar:
            return String(localized: "This calendar is read-only.", comment: "Create event error")
        }
    }
}

enum CalendarParticipationError: Error, LocalizedError {
    case eventNotFound
    case notAnInvitation
    case kvoFailed

    var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return String(localized: "The event could not be found.", comment: "RSVP error")
        case .notAnInvitation:
            return String(localized: "This event is not a meeting invitation.", comment: "RSVP error")
        case .kvoFailed:
            return String(localized: "Could not update response", comment: "RSVP failure title")
        }
    }
}
