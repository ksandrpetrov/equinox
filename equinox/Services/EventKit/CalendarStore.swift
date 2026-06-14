import EventKit
import Foundation

actor CalendarStore {
    private let store = EKEventStore()
    private let calendar: Calendar
    private let isNativeAppInstalled: NativeAppInstalledChecker
    private let externalChangeDispatcher = ExternalChangeDispatcher()
    private var storeObserver: NSObjectProtocol?

    private var eventsForDate: [Date: [DayEvent]] = [:]
    private var selectedCalendarEventsByDate: [Date: [DayEvent]] = [:]
    private var calendarEntriesStorage: [CalendarListEntry] = []
    private var previouslyFetchedJulians = IndexSet()
    private var visibleStart = CalendarDate(year: 1583, monthIndex: 0, day: 1)
    private var visibleEnd = CalendarDate(year: 1583, monthIndex: 0, day: 1)
    private(set) var isFetchingEvents = false
    private(set) var lastFetchError: String?

    var hasCalendarAccess: Bool {
        accessStatus() == .authorized
    }

    func accessStatus() -> CalendarAccessStatus {
        CalendarAccessStatus.from(EKEventStore.authorizationStatus(for: .event))
    }

    func hasSelectedCalendars() -> Bool {
        calendarEntriesStorage.contains { entry in
            if case .calendar(let cal) = entry { return cal.isSelected }
            return false
        }
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
            externalChangeDispatcher.handler()
        }
    }

    func setExternalChangeHandler(_ handler: @escaping @Sendable () -> Void) {
        externalChangeDispatcher.handler = handler
    }

    deinit {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
    }

    func setVisibleRange(first: CalendarDate, last: CalendarDate) {
        visibleStart = first
        visibleEnd = last
    }

    func selectedCalendarEvents() -> [CalendarDate: [DayEvent]] {
        var result: [CalendarDate: [DayEvent]] = [:]
        for (date, events) in selectedCalendarEventsByDate {
            result[CalendarDate(date: date, calendar: calendar)] = events
        }
        return result
    }

    func events(for date: CalendarDate) -> [DayEvent] {
        selectedCalendarEventsByDate[date.date(in: calendar)] ?? []
    }

    func calendarEntries() -> [CalendarListEntry] {
        calendarEntriesStorage
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

    func fetchEvents() async {
        isFetchingEvents = true
        lastFetchError = nil
        await fetchEventsWithStartDate(visibleStart, endDate: visibleEnd, refetch: false)
        isFetchingEvents = false
    }

    func refetchAll() async {
        isFetchingEvents = true
        lastFetchError = nil
        await fetchSourcesAndCalendars()
        await fetchEventsWithStartDate(visibleStart, endDate: visibleEnd, refetch: true)
        isFetchingEvents = false
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
        calendarEntriesStorage = calendarEntriesStorage.map { entry in
            switch entry {
            case .source:
                return entry
            case .calendar(var cal):
                if cal.id == identifier {
                    cal.isSelected = selected
                }
                return .calendar(cal)
            }
        }
        persistSelectedCalendars()
        await filterEvents()
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

    private func fetchSourcesAndCalendars() async {
        let listItems = store.calendars(for: .event).map {
            EventKitCalendarMapping.calendarListItem(from: $0)
        }

        let calendars = CalendarListing.filterDisplayableCalendars(
            CalendarListing.sortCalendarsForDisplay(listItems)
        )

        var inMemorySelections: [String: Bool] = [:]
        for entry in calendarEntriesStorage {
            if case .calendar(let cal) = entry {
                inMemorySelections[cal.id] = cal.isSelected
            }
        }

        let storedSelection = CalendarSelectionStorage.loadSelectedIDs()
        var selectedCalendars: Set<String>
        if storedSelection.isEmpty, !calendars.isEmpty {
            let allIDs = calendars.map(\.id)
            CalendarSelectionStorage.saveSelectedIDs(allIDs)
            selectedCalendars = Set(allIDs)
        } else {
            selectedCalendars = Set(storedSelection)
        }

        var result: [CalendarListEntry] = []
        var currentSourceTitle = ""

        for item in calendars {
            guard let ekCalendar = store.calendar(withIdentifier: item.id) else { continue }
            let calendarSourceTitle = item.sourceTitle

            if calendarSourceTitle != currentSourceTitle {
                result.append(.source(calendarSourceTitle))
                currentSourceTitle = calendarSourceTitle
            }
            let identifier = item.id
            let isSelected = inMemorySelections[identifier] ?? selectedCalendars.contains(identifier)
            result.append(.calendar(SelectableCalendar.from(
                calendar: ekCalendar,
                sourceTitle: calendarSourceTitle,
                isSelected: isSelected
            )))
        }

        persistSelectedCalendars(from: result)
        calendarEntriesStorage = result
    }

    private func persistSelectedCalendars(from entries: [CalendarListEntry]? = nil) {
        let source = entries ?? calendarEntriesStorage
        let ids = source.compactMap { entry -> String? in
            guard case .calendar(let cal) = entry, cal.isSelected else { return nil }
            return cal.id
        }
        CalendarSelectionStorage.saveSelectedIDs(ids)
    }

    private func validCalendars() -> [EKCalendar] {
        calendarEntriesStorage.compactMap { entry -> EKCalendar? in
            guard case .calendar(let cal) = entry, cal.isSelected else { return nil }
            return store.calendar(withIdentifier: cal.id)
        }
    }

    private func fetchEventsWithStartDate(
        _ startDate: CalendarDate,
        endDate: CalendarDate,
        refetch: Bool
    ) async {
        guard hasCalendarAccess else {
            lastFetchError = String(localized: "Calendar access is required to load events.", comment: "Fetch error")
            return
        }

        if refetch {
            previouslyFetchedJulians = IndexSet()
            eventsForDate = [:]
        }

        let dateRange = startDate.julian..<(endDate.julian + 1)
        if previouslyFetchedJulians.contains(integersIn: dateRange) {
            return
        }

        var notYetFetchedDates = IndexSet()
        for julian in startDate.julian...endDate.julian {
            if !previouslyFetchedJulians.contains(julian) {
                notYetFetchedDates.insert(julian)
            }
        }

        var fetchStart = startDate
        var fetchEnd = endDate
        if let first = notYetFetchedDates.first, let last = notYetFetchedDates.last {
            fetchStart = CalendarDate(julian: first)
            fetchEnd = CalendarDate(julian: last)
        }

        previouslyFetchedJulians.insert(integersIn: dateRange)

        let rangeStart = fetchStart.date(in: calendar)
        let rangeEnd = fetchEnd.date(in: calendar)
        let cals = validCalendars()
        let predicate = store.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: cals)
        let events = store.events(matching: predicate)
        let newEventsForDate = await buildDayEvents(from: events, rangeStart: rangeStart, rangeEnd: rangeEnd)
        eventsForDate.merge(newEventsForDate) { _, new in new }
        await filterEvents()
    }

    /// Builds display-ready `DayEvent` day slots for EventKit events. Shared by the
    /// visible-range fetch and the Plaud history match so layout/join-URL logic stays in one place.
    private func buildDayEvents(
        from events: [EKEvent],
        rangeStart: Date,
        rangeEnd: Date
    ) async -> [Date: [DayEvent]] {
        var newEventsForDate: [Date: [DayEvent]] = [:]

        for event in events {
            let layoutInput = EventLayoutInput(
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarTitle: event.calendar.title
            )
            let slots = layoutEventDaySlots(
                event: layoutInput,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                calendar: calendar
            )
            let webJoinURL = JoinURLDetection.detectJoinURL(
                location: event.location,
                url: event.url?.absoluteString,
                notes: event.hasNotes ? event.notes : nil
            )
            let joinURL: URL?
            if let webJoinURL {
                joinURL = await resolveNativeJoinURL(from: webJoinURL) ?? webJoinURL
            } else {
                joinURL = nil
            }

            for slot in slots {
                let dayEvent = DayEventMapping.dayEvent(
                    from: event,
                    slot: slot,
                    joinURL: joinURL,
                    dayKey: slot.dayStart
                )
                if newEventsForDate[slot.dayStart] == nil {
                    newEventsForDate[slot.dayStart] = []
                }
                newEventsForDate[slot.dayStart]?.append(dayEvent)
            }
        }

        for date in newEventsForDate.keys {
            newEventsForDate[date]?.sort { lhs, rhs in
                precedesInDisplayOrder(
                    EventSortKey(
                        isEventAllDay: lhs.isEventAllDay,
                        isSlotAllDay: lhs.isSlotAllDay,
                        calendarTitle: lhs.calendarTitle,
                        startDate: lhs.startDate
                    ),
                    EventSortKey(
                        isEventAllDay: rhs.isEventAllDay,
                        isSlotAllDay: rhs.isSlotAllDay,
                        calendarTitle: rhs.calendarTitle,
                        startDate: rhs.startDate
                    )
                )
            }
        }

        return newEventsForDate
    }

    /// Returns selected-calendar events across an arbitrary span without mutating the display
    /// cache. Plaud matching uses this so links resolve for meetings outside the visible range.
    /// One `DayEvent` per underlying event (deduplicated across multi-day slots).
    func matchableEvents(from start: Date, to end: Date) async -> [DayEvent] {
        guard hasCalendarAccess, start < end else { return [] }
        let cals = validCalendars()
        guard !cals.isEmpty else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: cals)
        let events = store.events(matching: predicate)
        let byDate = await buildDayEvents(from: events, rangeStart: start, rangeEnd: end)

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

    private func filterEvents() async {
        var filtered: [Date: [DayEvent]] = [:]
        let selectedCalendars = Set(validCalendarIDs())

        for (date, events) in eventsForDate {
            for event in events where selectedCalendars.contains(event.calendarIdentifier) {
                if filtered[date] == nil {
                    filtered[date] = []
                }
                filtered[date]?.append(event)
            }
        }

        selectedCalendarEventsByDate = filtered
    }

    private func validCalendarIDs() -> [String] {
        calendarEntriesStorage.compactMap { entry -> String? in
            guard case .calendar(let cal) = entry, cal.isSelected else { return nil }
            return cal.id
        }
    }

    private func resolveNativeJoinURL(from url: URL) async -> URL? {
        await NativeJoinURLResolver.resolveNativeJoinURL(from: url, isAppInstalled: isNativeAppInstalled)
    }
}

private final class ExternalChangeDispatcher: @unchecked Sendable {
    var handler: @Sendable () -> Void = {}
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
