import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Persists under `KeyboardShortcuts_GlobalShortcut` — renaming `kKeyboardShortcut` resets the user's shortcut.
    static let togglePanel = Self(kKeyboardShortcut)
}
