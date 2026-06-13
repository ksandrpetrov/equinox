import Foundation
import KeyboardShortcuts

enum KeyboardShortcutMigration {
    private static let migrationFlagKey = "KeyboardShortcutsMigrationFromMASShortcut"

    /// Converts legacy MASShortcut `GlobalShortcut` dictionary to KeyboardShortcuts storage.
    @MainActor
    static func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationFlagKey) else { return }

        if KeyboardShortcuts.getShortcut(for: .togglePanel) != nil {
            UserDefaults.standard.set(true, forKey: migrationFlagKey)
            return
        }

        guard let dict = UserDefaults.standard.dictionary(forKey: kKeyboardShortcut) else {
            UserDefaults.standard.set(true, forKey: migrationFlagKey)
            return
        }

        let keyCode = intValue(from: dict["keyCode"])
        let modifierFlags = intValue(from: dict["modifierFlags"])
        guard let keyCode, let modifierFlags else {
            UserDefaults.standard.set(true, forKey: migrationFlagKey)
            return
        }

        let shortcut = KeyboardShortcuts.Shortcut(carbonKeyCode: keyCode, carbonModifiers: modifierFlags)
        KeyboardShortcuts.setShortcut(shortcut, for: .togglePanel)
        UserDefaults.standard.set(true, forKey: migrationFlagKey)
    }

    private static func intValue(from value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }
}
