import EventKit
import Foundation

actor CalendarStore: CalendarEventStore {
    private let store = EKEventStore()
    private let calendar: Calendar
    private let isNativeAppInstalled: NativeAppInstalledChecker
    private var externalChangeHandler: (@Sendable () -> Void)?
    private var hasPendingExternalChange = false
    private nonisolated(unsafe) var storeObserver: NSObjectProtocol?

    private var fetchCache = EventFetchCache()
    private var calendarSelection = CalendarSelectionService()
    private var previousAccessStatus: CalendarAccessStatus?
    private var needsPreparation = true
    private var hasCompletedInitialLoad = false

    var hasCalendarAccess: Bool {
        accessStatus() == .authorized
    }

    func accessStatus() -> CalendarAccessStatus {
        let status = CalendarAccessMapping.guiAccessStatus()
        if status != previousAccessStatus {
            previousAccessStatus = status
            invalidateEvents()
        }
        if !status.isAuthorized {
            fetchCache.clearEvents()
            hasCompletedInitialLoad = false
        }
        return status
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
        ) { [weak self] _ in
            Task { await self?.handleExternalChange() }
        }
    }

    func setExternalChangeHandler(_ handler: @escaping @Sendable () -> Void) {
        externalChangeHandler = handler
        if hasPendingExternalChange {
            hasPendingExternalChange = false
            handler()
        }
    }

    deinit {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
    }

    func snapshot() -> CalendarStoreSnapshot {
        let status = accessStatus()
        return CalendarStoreSnapshot(
            accessStatus: status,
            eventsByDate: status.isAuthorized ? fetchCache.selectedCalendarEvents(calendar: calendar) : [:],
            calendarEntries: status.isAuthorized ? calendarSelection.calendarEntries : [],
            defaultCalendarIdentifier: status.isAuthorized ? defaultCalendarIdentifierForNewEvents() : nil,
            hasSelectedCalendars: status.isAuthorized && calendarSelection.hasSelectedCalendars(),
            lastFetchError: fetchCache.lastFetchError,
            hasCompletedInitialLoad: hasCompletedInitialLoad
        )
    }

    private func defaultCalendarIdentifierForNewEvents() -> String? {
        guard let calendar = store.defaultCalendarForNewEvents,
              calendar.allowsContentModifications else { return nil }
        return calendar.calendarIdentifier
    }

    func requestCalendarAccessIfNeeded() async -> Bool {
        switch accessStatus() {
        case .authorized:
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
            return true
        }
        fetchCache.clearEvents()
        return false
    }

    func fetchEvents(first: CalendarDate, last: CalendarDate, refetch: Bool = false) async -> Bool {
        guard first.isValid, last.isValid, first <= last else { return false }
        guard hasCalendarAccess else { return false }
        if needsPreparation || refetch { prepareStore() }
        let revision = fetchCache.revision
        let primarySucceeded = await fetchEventsWithStartDate(
            first,
            endDate: last,
            refetch: refetch
        )
        guard primarySucceeded, fetchCache.revision == revision else { return false }

        let today = CalendarDate.today(calendar: calendar)
        let meetingMonitorLast = min(today.addingDays(1), CalendarDate.maximumSupported)
        var retainedRanges = [(first: first, last: last)]
        if today < first || meetingMonitorLast > last {
            let todaySucceeded = await fetchEventsWithStartDate(
                today,
                endDate: meetingMonitorLast,
                refetch: refetch
            )
            guard todaySucceeded, fetchCache.revision == revision else { return false }
            retainedRanges.append((first: today, last: meetingMonitorLast))
        }
        fetchCache.retainEvents(inside: retainedRanges, calendar: calendar)
        applyCalendarFilter()
        hasCompletedInitialLoad = true
        return true
    }

    func refetchAll(first: CalendarDate, last: CalendarDate) async -> Bool {
        await fetchEvents(first: first, last: last, refetch: true)
    }

    func createEvent(from draft: NewEventDraft) throws {
        try draft.validate(calendar: calendar)
        guard hasCalendarAccess else { throw CalendarStoreError.calendarAccessRequired }
        guard let ekCalendar = store.calendar(withIdentifier: draft.calendarIdentifier) else {
            throw CalendarStoreError.calendarNotFound
        }
        guard ekCalendar.allowsContentModifications else {
            throw CalendarStoreError.readOnlyCalendar
        }
        let event = EKEvent(eventStore: store)
        EventKitMutation.applyCreate(from: draft, to: event, calendar: ekCalendar)

        try store.save(event, span: .thisEvent, commit: true)
        invalidateEvents()
    }

    func deleteEvent(identifier: String, occurrenceStartDate: Date) throws {
        guard hasCalendarAccess else { throw CalendarStoreError.calendarAccessRequired }
        guard occurrenceStartDate.timeIntervalSinceReferenceDate.isFinite else {
            throw CalendarStoreError.eventNotFound
        }
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
        var eventCalendar = calendar
        if let timeZone = event.timeZone { eventCalendar.timeZone = timeZone }
        let isFinalDay = isFinalRecurrenceDay(
            occurrenceDate: event.occurrenceDate ?? occurrenceStartDate,
            ruleEndDates: (event.recurrenceRules ?? []).map { $0.recurrenceEnd?.endDate },
            isDetached: event.isDetached,
            calendar: eventCalendar
        )
        // On macOS, removing the final dated occurrence with .thisEvent can restore
        // excluded earlier dates as a standalone event. Truncation preserves those
        // exclusions and affects only this occurrence when every rule ends on its day.
        try store.remove(event, span: isFinalDay ? .futureEvents : .thisEvent, commit: true)
        invalidateEvents()
    }

    func updateSelectedCalendar(identifier: String, selected: Bool) async {
        calendarSelection.updateSelectedCalendar(identifier: identifier, selected: selected)
        invalidateEvents()
        applyCalendarFilter()
    }

    func resetCalendarSelection() {
        calendarSelection = CalendarSelectionService()
        invalidateEvents()
        guard hasCalendarAccess else {
            applyCalendarFilter()
            return
        }
        prepareStore()
        applyCalendarFilter()
    }

    func invalidateTimeContext() {
        fetchCache.clearEvents()
        needsPreparation = true
        hasCompletedInitialLoad = false
    }

    // MARK: - Private

    private func invalidateEvents() {
        fetchCache.invalidate()
        needsPreparation = true
    }

    private func handleExternalChange() {
        invalidateEvents()
        if let externalChangeHandler {
            externalChangeHandler()
        } else {
            hasPendingExternalChange = true
        }
    }

    private func prepareStore() {
        fetchCache.invalidate()
        refreshEventKitStore()
        calendarSelection.refresh(from: store)
        needsPreparation = false
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
        refetch: Bool
    ) async -> Bool {
        guard hasCalendarAccess else {
            fetchCache.clearEvents()
            fetchCache.lastFetchError = String(localized: "Calendar access is required to load events.", bundle: .equinox, comment: "Fetch error")
            return false
        }

        guard let fetchRange = fetchCache.prepareFetchRange(first: startDate, last: endDate, refetch: refetch) else {
            fetchCache.lastFetchError = nil
            return true
        }

        let revision = fetchCache.revision
        let cals = calendarSelection.validCalendars(from: store)
        var newEventsForDate: [Date: [DayEvent]] = [:]
        if !cals.isEmpty {
            for chunk in EventFetchRange.chunks(first: fetchRange.fetchStart, last: fetchRange.fetchEnd) {
                let rangeStart = chunk.first.date(in: calendar)
                let rangeEnd = chunk.last.addingDays(1).date(in: calendar)
                let predicate = store.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: cals)
                let sources = store.events(matching: predicate).map(DayEventSource.extract(from:))
                let chunkEvents = await DayEventBuilder.buildDayEvents(
                    from: sources,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                    calendar: calendar,
                    resolveNativeJoinURL: { [isNativeAppInstalled] url in
                        await NativeJoinURLResolver.resolveNativeJoinURL(from: url, isAppInstalled: isNativeAppInstalled)
                    }
                )
                guard hasCalendarAccess, fetchCache.revision == revision else { return false }
                newEventsForDate.merge(chunkEvents) { _, new in new }
            }
        }
        guard fetchCache.commitFetch(newEventsForDate, plan: fetchRange, calendar: calendar) else {
            return false
        }
        return true
    }

    private func applyCalendarFilter() {
        fetchCache.applyCalendarFilter(selectedCalendarIDs: calendarSelection.selectedCalendarIDs())
    }

}
