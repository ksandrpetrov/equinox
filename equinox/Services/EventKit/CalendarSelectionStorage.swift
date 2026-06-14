import Foundation

enum CalendarSelectionStorage {
    static func loadSelectedIDs() -> [String] {
        UserDefaults.standard.array(forKey: kSelectedCalendars) as? [String] ?? []
    }

    static func saveSelectedIDs(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: kSelectedCalendars)
    }

    static func clearSelection() {
        UserDefaults.standard.removeObject(forKey: kSelectedCalendars)
    }
}
