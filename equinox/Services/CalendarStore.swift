import AppKit
import EventKit
import Foundation

actor CalendarStore {
    private let store = EKEventStore()
    private let calendar: Calendar
    private let onUpdated: @Sendable () -> Void

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

    var defaultCalendarIdentifier: String {
        store.defaultCalendarForNewEvents?.calendarIdentifier ?? ""
    }

    init(calendar: Calendar, onUpdated: @escaping @Sendable () -> Void) {
        self.calendar = calendar
        self.onUpdated = onUpdated
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

    func refreshEventKitStore() {
        store.reset()
        store.refreshSourcesIfNecessary()
    }

    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        store.calendar(withIdentifier: identifier)
    }

    func createEvent(from draft: NewEventDraft) throws {
        guard let ekCalendar = store.calendar(withIdentifier: draft.calendarIdentifier) else {
            throw CalendarStoreError.calendarNotFound
        }
        guard ekCalendar.allowsContentModifications else {
            throw CalendarStoreError.readOnlyCalendar
        }

        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.location = draft.location.isEmpty ? nil : draft.location
        event.url = draft.url
        event.isAllDay = draft.isAllDay
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.calendar = ekCalendar
        event.notes = draft.notes
        event.timeZone = draft.isAllDay ? nil : TimeZone.current

        if let recurrence = draft.recurrence {
            event.recurrenceRules = [recurrenceRule(from: recurrence)]
        }

        if let offset = draft.alertOffset {
            for alarm in event.alarms ?? [] { event.removeAlarm(alarm) }
            event.addAlarm(EKAlarm(relativeOffset: offset))
        }

        try store.save(event, span: .thisEvent, commit: true)
    }

    func deleteEvent(identifier: String) throws {
        guard let event = store.event(withIdentifier: identifier) else {
            throw CalendarStoreError.eventNotFound
        }
        try store.remove(event, span: .thisEvent, commit: true)
    }

    func save(_ event: EKEvent) throws {
        try store.save(event, span: .thisEvent, commit: true)
    }

    func remove(_ event: EKEvent, span: EKSpan) throws {
        try store.remove(event, span: span, commit: true)
    }

    func setParticipationStatus(_ status: EventParticipationStatus, for eventID: String) async throws {
        guard let event = store.event(withIdentifier: eventID) else {
            throw CalendarParticipationError.eventNotFound
        }
        guard event.hasAttendees else {
            throw CalendarParticipationError.notAnInvitation
        }
        event.setValue(status.rawValue, forKey: "participationStatus")
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

    private func fetchSourcesAndCalendars() async {
        let calendars = store.calendars(for: .event).sorted { cal1, cal2 in
            if cal1.source.sourceIdentifier == cal2.source.sourceIdentifier {
                return cal1.title.localizedStandardCompare(cal2.title) == .orderedAscending
            }
            return cal1.source.title.localizedStandardCompare(cal2.source.title) == .orderedAscending
        }

        var inMemorySelections: [String: Bool] = [:]
        for entry in calendarEntriesStorage {
            if case .calendar(let cal) = entry {
                inMemorySelections[cal.id] = cal.isSelected
            }
        }

        let storedSelection = CalendarSelectionStorage.loadSelectedIDs()
        var selectedCalendars: Set<String>
        if storedSelection.isEmpty, !calendars.isEmpty {
            let allIDs = calendars.map(\.calendarIdentifier)
            CalendarSelectionStorage.saveSelectedIDs(allIDs)
            selectedCalendars = Set(allIDs)
        } else {
            selectedCalendars = Set(storedSelection)
        }

        var result: [CalendarListEntry] = []
        var currentSourceTitle = ""

        for ekCalendar in calendars {
            let calendarSourceTitle = ekCalendar.source.title
            guard ekCalendar.color != nil else { continue }

            if calendarSourceTitle != currentSourceTitle {
                result.append(.source(calendarSourceTitle))
                currentSourceTitle = calendarSourceTitle
            }
            let identifier = ekCalendar.calendarIdentifier
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
            let joinURL = webJoinURL.map { resolveNativeJoinURL(from: $0) ?? $0 }

            for slot in slots {
                let dayEvent = DayEvent.from(
                    event: event,
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

        eventsForDate.merge(newEventsForDate) { _, new in new }
        await filterEvents()
    }

    private func filterEvents() async {
        var filtered: [Date: [DayEvent]] = [:]
        let selectedCalendars = Set(CalendarSelectionStorage.loadSelectedIDs())

        for (date, events) in eventsForDate {
            for event in events where selectedCalendars.contains(event.calendarIdentifier) {
                if filtered[date] == nil {
                    filtered[date] = []
                }
                filtered[date]?.append(event)
            }
        }

        selectedCalendarEventsByDate = filtered
        onUpdated()
    }

    private func resolveNativeJoinURL(from url: URL) -> URL? {
        guard let scheme = NativeJoinURL.nativeScheme(for: url),
              let schemeURL = URL(string: scheme),
              NSWorkspace.shared.urlForApplication(toOpen: schemeURL) != nil,
              let native = NativeJoinURL.nativeURLString(from: url) else {
            return nil
        }
        return URL(string: native)
    }

    private func recurrenceRule(from draft: RecurrenceDraft) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency
        var interval = 1
        switch draft.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .biweekly: frequency = .weekly; interval = 2
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }
        let end = draft.endDate.map { EKRecurrenceEnd(end: $0) }
        return EKRecurrenceRule(recurrenceWith: frequency, interval: interval, end: end)
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

    var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return String(localized: "The event could not be found.", comment: "RSVP error")
        case .notAnInvitation:
            return String(localized: "This event is not a meeting invitation.", comment: "RSVP error")
        }
    }
}
