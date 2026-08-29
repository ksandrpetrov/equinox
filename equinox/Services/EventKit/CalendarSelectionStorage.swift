import Foundation

enum CalendarSelectionStorage {
    static func hasStoredSelection(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: kSelectedCalendars) != nil
    }

    static func loadSelectedIDs(from defaults: UserDefaults = .standard) -> [String] {
        defaults.array(forKey: kSelectedCalendars) as? [String] ?? []
    }

    static func saveSelectedIDs(_ ids: [String], to defaults: UserDefaults = .standard) {
        defaults.set(ids, forKey: kSelectedCalendars)
    }

    static func clearSelection(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: kSelectedCalendars)
    }
}
