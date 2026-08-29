import EventKit
import Foundation

/// Calendar list, selection persistence, and valid-calendar resolution for `CalendarStore`.
struct CalendarSelectionService {
    private(set) var calendarEntriesStorage: [CalendarListEntry] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var calendarEntries: [CalendarListEntry] {
        calendarEntriesStorage
    }

    func hasSelectedCalendars() -> Bool {
        calendarEntriesStorage.contains { entry in
            if case .calendar(let cal) = entry { return cal.isSelected }
            return false
        }
    }

    mutating func refresh(from store: EKEventStore) {
        let calendars = EventKitCalendarMapping.displayableCalendarItems(from: store)

        var inMemorySelections: [String: Bool] = [:]
        for entry in calendarEntriesStorage {
            if case .calendar(let cal) = entry {
                inMemorySelections[cal.id] = cal.isSelected
            }
        }

        let hadStoredSelection = CalendarSelectionStorage.hasStoredSelection(in: defaults)
        let storedSelection = CalendarSelectionStorage.loadSelectedIDs(from: defaults)
        let selectedCalendars: Set<String>
        if !hadStoredSelection, !calendars.isEmpty {
            let allIDs = calendars.map(\.id)
            CalendarSelectionStorage.saveSelectedIDs(allIDs, to: defaults)
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
            let isSelected = inMemorySelections[item.id] ?? selectedCalendars.contains(item.id)
            result.append(.calendar(SelectableCalendar.from(
                item,
                calendar: ekCalendar,
                isSelected: isSelected
            )))
        }

        // Do not turn a temporarily empty EventKit store into an explicit "select none"
        // preference. That would keep future calendars hidden after access/account changes.
        if Self.shouldPersistSelection(discoveredCalendarCount: calendars.count) {
            persistSelectedCalendars(from: result)
        }
        calendarEntriesStorage = result
    }

    static func shouldPersistSelection(discoveredCalendarCount: Int) -> Bool {
        discoveredCalendarCount > 0
    }

    mutating func updateSelectedCalendar(identifier: String, selected: Bool) {
        var didFindCalendar = false
        calendarEntriesStorage = calendarEntriesStorage.map { entry in
            switch entry {
            case .source:
                return entry
            case .calendar(var cal):
                if cal.id == identifier {
                    didFindCalendar = true
                    cal.isSelected = selected
                }
                return .calendar(cal)
            }
        }
        guard didFindCalendar else { return }
        persistSelectedCalendars()
    }

    func validCalendars(from store: EKEventStore) -> [EKCalendar] {
        calendarEntriesStorage.compactMap { entry -> EKCalendar? in
            guard case .calendar(let cal) = entry, cal.isSelected else { return nil }
            return store.calendar(withIdentifier: cal.id)
        }
    }

    func selectedCalendarIDs() -> Set<String> {
        Set(calendarEntriesStorage.compactMap { entry -> String? in
            guard case .calendar(let cal) = entry, cal.isSelected else { return nil }
            return cal.id
        })
    }

    private func persistSelectedCalendars(from entries: [CalendarListEntry]? = nil) {
        let source = entries ?? calendarEntriesStorage
        let discoveredIDs = Set(source.compactMap { entry -> String? in
            guard case .calendar(let cal) = entry else { return nil }
            return cal.id
        })
        let selectedDiscoveredIDs = source.compactMap { entry -> String? in
            guard case .calendar(let cal) = entry, cal.isSelected else { return nil }
            return cal.id
        }
        let ids = Self.selectionIDsToPersist(
            selectedDiscoveredIDs: selectedDiscoveredIDs,
            discoveredIDs: discoveredIDs,
            storedSelectedIDs: CalendarSelectionStorage.loadSelectedIDs(from: defaults)
        )
        CalendarSelectionStorage.saveSelectedIDs(ids, to: defaults)
    }

    static func selectionIDsToPersist(
        selectedDiscoveredIDs: [String],
        discoveredIDs: Set<String>,
        storedSelectedIDs: [String]
    ) -> [String] {
        var seen = Set<String>()
        return (selectedDiscoveredIDs + storedSelectedIDs.filter { !discoveredIDs.contains($0) })
            .filter { seen.insert($0).inserted }
    }
}
