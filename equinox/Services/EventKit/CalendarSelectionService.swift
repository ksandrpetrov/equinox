import EventKit
import Foundation

/// Calendar list, selection persistence, and valid-calendar resolution for `CalendarStore`.
struct CalendarSelectionService {
    private(set) var calendarEntriesStorage: [CalendarListEntry] = []

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

        let storedSelection = CalendarSelectionStorage.loadSelectedIDs()
        let selectedCalendars: Set<String>
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
            let isSelected = inMemorySelections[item.id] ?? selectedCalendars.contains(item.id)
            result.append(.calendar(SelectableCalendar.from(
                item,
                calendar: ekCalendar,
                isSelected: isSelected
            )))
        }

        persistSelectedCalendars(from: result)
        calendarEntriesStorage = result
    }

    mutating func updateSelectedCalendar(identifier: String, selected: Bool) {
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

    private mutating func persistSelectedCalendars(from entries: [CalendarListEntry]? = nil) {
        let source = entries ?? calendarEntriesStorage
        let ids = source.compactMap { entry -> String? in
            guard case .calendar(let cal) = entry, cal.isSelected else { return nil }
            return cal.id
        }
        CalendarSelectionStorage.saveSelectedIDs(ids)
    }
}
